package Faux::Context;

use strict;
use warnings;

########################################################################
sub new {
########################################################################
  my ( $class, %options ) = @_;

  my $self = bless \%options, $class;

  return $self;
}

########################################################################
sub cgi_header_in    { }
sub send_http_header { }
sub cgi_header_out   { }
########################################################################

########################################################################
sub getCookieValue {
########################################################################
  my ( $self, $name ) = @_;

  return $ENV{$name};
}

########################################################################
sub getInputValue {
########################################################################
  my ( $self, $name ) = @_;

  return $ENV{$name};
}

########################################################################
package main;
########################################################################

use strict;
use warnings;

use lib qw(.);

use Test::More;

use Bedrock qw(slurp_file);

use Apache::Bedrock qw(bind_module);
use Bedrock::BedrockConfig;
use Bedrock::Constants qw(:defaults :chars :booleans);
use Bedrock::XML;
use Cwd;
use Data::Dumper;
use DBI;
use English qw(-no_match_vars);
use File::Temp qw(tempfile tempdir);

use_ok('BLM::Startup::SQLiteSession');

########################################################################
sub get_module_config {
########################################################################
  my $fh = *DATA;

  my $config = Bedrock::XML->new($fh);
  my ( undef, $filename ) = tempfile( TEMPLATE => 'XXXXXX', UNLINK => $TRUE );

  my $session_config = $config->{config};

  $session_config->{data_source} = sprintf $session_config->{data_source}, $filename;

  $session_config->{cookieless_sessions} = $TRUE;

  $session_config->{verbose} = $FALSE;

  return $session_config;
}

########################################################################
sub create_session_table {
########################################################################
  my ($dbi) = @_;

  my $sql = << 'END_OF_SQL';
create table session
  (
   id           integer primary key autoincrement not null,
   session      varchar(50)  not null default '',
   login_cookie varchar(50)  not null default '',
   username     varchar(50)  not null default '',
   password     varchar(30)  default null,
   firstname    varchar(30)  default null,
   lastname     varchar(50)  default null,
   email        varchar(100) default null,
   prefs        text,
   updated      timestamp    not null default current_timestamp,
   added        datetime     default null,
   expires      datetime     default null
 );
END_OF_SQL

  return $dbi->do($sql);
}

my $module_config = get_module_config;

my $ctx = Faux::Context->new( CONFIG => { SESSION_DIR => tempdir( CLEANUP => 1 ) } );

my $session;
my $dbi;

########################################################################
subtest 'bind module' => sub {
########################################################################

  my $dsn = $module_config->{data_source};

  $dbi = eval { return DBI->connect( $dsn, undef, undef, { PrintError => 0 } ); };

  isa_ok( $dbi, 'DBI::db' )
    or BAIL_OUT($EVAL_ERROR);

  eval { return create_session_table($dbi); };

  ok( !$EVAL_ERROR, 'create session table' )
    or BAIL_OUT($EVAL_ERROR);

  $session = eval {
    return bind_module(
      context => $ctx,
      config  => $module_config,
      module  => 'BLM::Startup::SQLiteSession'
    );
  };

  ok( !$EVAL_ERROR, 'bound module' )
    or BAIL_OUT($EVAL_ERROR);

  isa_ok( $session, 'BLM::Startup::SQLiteSession' )
    or do {
    diag( Dumper( [$session] ) );
    BAIL_OUT('session is not instantiated properly');
    };
};

########################################################################
subtest 'session id' => sub {
########################################################################
  ok( $session->{session}, 'session id exists' );

  like( $session->{session}, qr/^[\da-f]{32}$/xsm, 'session is a md5 hash' );
};

########################################################################
subtest 'create_session_dir' => sub {
########################################################################
  my $session_dir = $session->create_session_dir;

  ok( $session_dir, 'create_session_dir() - returns a directory' );

  ok( -d $session_dir, 'create_session_dir() - directory exists' );

  ok( -w $session_dir, 'create_session_dir() - session is writeable' );
};

########################################################################
subtest 'create_session_file' => sub {
########################################################################
  my $file = $session->create_session_file( 'test.jroc', $module_config );

  ok( -s $file, 'file written' );

  my $obj = eval {
    require JSON;

    my $content = slurp_file $file;

    return JSON->new->decode($content);
  };

  is_deeply( $obj, $module_config, 'object serialized correctly' )
    or diag( Dumper( [ $obj, $module_config ] ) );

  unlink $file;

  my $session_dir = $session->create_session_dir;

  rmdir $session_dir;
};

my $session_id = $session->{session};

########################################################################
subtest 'close' => sub {
########################################################################
  $session->{foo} = 'bar';

  eval { return $session->closeBLM; };

  ok( !$EVAL_ERROR, 'closeBLM' )
    or diag( Dumper( [$EVAL_ERROR] ) );
};

########################################################################
subtest 'save' => sub {
########################################################################
  $ENV{session} = $session_id;

  $session = eval {
    return bind_module(
      context => $ctx,
      config  => $module_config,
      module  => 'BLM::Startup::SQLiteSession'
    );
  };

  is( $session->{foo}, 'bar', 'session saved' )
    or diag( Dumper( [$session] ) );
};

########################################################################
subtest 'register' => sub {
########################################################################
  my $rc = eval {
    return $session->register( 'fflintstone', 'W1lma', 'Fred', 'Flintstone', 'fflintstone@openbedrock.net' );
  };

  if ( !$rc || $EVAL_ERROR ) {
    if ( $EVAL_ERROR =~ /username\sexists/xsm ) {
      diag('user exists...so presumably this worked at some point!');
    }
    else {
      BAIL_OUT( 'error trying to register a new user:' . $EVAL_ERROR );
    }
  }
  else {
    ok( $rc, 'registered user' );
  }

};

########################################################################
subtest 'login' => sub {
########################################################################
  eval { $session->login( 'fflintstone', 'Wilma' ); };

  ok( $EVAL_ERROR, 'bad login' );

  like( $EVAL_ERROR, qr/^Unable\sto\slogin\suser/xsm );

  my $session_id = $session->{session};

  eval { $session->login( 'fflintstone', 'W1lma' ); };

  ok( !$EVAL_ERROR, 'login fflintstone' )
    or diag( Dumper( [$EVAL_ERROR] ) );

  ok( $session_id ne $session->{session}, 'new session id' );

  ok( $session->{username} eq 'fflintstone', 'username is fflintstone' );
};

########################################################################
subtest 'remove user' => sub {
########################################################################

  ok( $session->remove_user( 'fflintstone', 'W1lma' ), 'remove user' );

  eval { $session->login( 'fflintstone', 'W1lma' ); };

  ok( $EVAL_ERROR, 'removed user cannot login' );
};

done_testing;

########################################################################
END {

}

1;

__DATA__
<object>
  <scalar name="binding">session</scalar>
  <scalar name="session">yes</scalar>
  <scalar name="module">BLM::Startup::SQLiteSession</scalar>
  <object name="config">
    <scalar name="data_source">dbi:SQLite:dbname=%s</scalar>
    <scalar name="table_name">session</scalar>
    <scalar name="verbose">2</scalar>
    <scalar name="param">session</scalar>
    <scalar name="login_cookie_name">session_login</scalar>
    <scalar name="login_cookie_expiry_days">365</scalar>
    <scalar name="purge_user_after">30</scalar>

    <object name="cookie">
      <scalar name="path">/</scalar>
      <scalar name="expiry_secs">3600</scalar>
      <scalar name="domain"></scalar>
    </object>
  </object>
</object>
