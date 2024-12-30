#!/usr/bin/env perl
# create a session table for BLM::Startup::SQLiteSession

use strict;
use warnings;

use BLM::Startup::SQLiteSession qw(create_encrypt_function);
use Carp;
use Data::Dumper;
use DBI;
use English qw(-no_match_vars);
use File::ShareDir qw(dist_dir);
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

########################################################################
sub create_database {
########################################################################
  my %options = @_;

  my $sql = eval {
    local $RS = undef;

    open my $fh, '<', sprintf '%s/%s', $options{dist_dir}, 'create-session-table.sql'
      or croak 'could not open create-session-table.sql';

    my $sql = <$fh>;
    close $fh;

    return $sql;
  };

  croak $EVAL_ERROR
    if !$sql;

  my $dsn = sprintf 'dbi:SQLite:dbname=%s', $options{database};

  my $dbi = DBI->connect( $dsn, undef, undef, { RaiseError => 1, PrintError => 0 } );

  $dbi->do($sql);

  create_encrypt_function($dbi);

  return $dbi;
}

########################################################################
sub create_user {
########################################################################
  my ( $dbi, %options ) = @_;

  my ( $user, $password, $firstname, $lastname, $email ) = @options{qw(user password firstname lastname email)};

  return
    if !$user || !$password;

  my $sql = <<'END_OF_SQL';
insert into session 
 (username, password, firstname, lastname, email) values ( ?, encrypt(?), ?, ?, ? )
END_OF_SQL

  my @bind_args = ( $user, $password, $firstname, $lastname, $email );

  eval { return $dbi->prepare($sql)->execute(@bind_args); };

  if ( $EVAL_ERROR && $EVAL_ERROR =~ /unique\sconstraint\sfailed/ixsm ) {

    croak 'to update a user, pass all options'
      if grep { !defined $options{$_} } qw(user password firstname lastname email);

    my $update_sql = <<'END_OF_SQL';
update session 
  set username = ?,
      password = encrypt(?),
      firstname = ?,
      lastname = ?,
      email = ?
  where username = ?
END_OF_SQL

    my $sth = $dbi->prepare($update_sql);
    $sth->execute( @bind_args, $user );
  }

  return;
}

########################################################################
sub main {
########################################################################
  my @option_specs = qw(
    help
    database|d=s
    user|u=s
    password|p=s
    firstname|f=s
    lastname|l=s
    email|e=s
  );

  my %options;

  my $retval = GetOptions( \%options, @option_specs );

  if ( !$retval || $options{help} ) {
    pod2usage(1);
  }

  my $path = dist_dir('BLM-Startup-SQLiteSession');

  croak 'unable to find distribution path'
    if !$path;

  $options{dist_dir} = $path;

  croak 'database is a required argument'
    if !$options{database};

  my $dbi = create_database(%options);

  create_user( $dbi, %options );

  return 0;
}

exit main();

1;

__END__

=pod

=head1 SYNOPSIS

 create-session-table.pl --database database-name [--user user --password password --help]

Creates a session table for storing persistent Bedrock sessions.
Optionally creates a login user. If you want to create or update a user, --user
and --password are required arguments.

=head1 OPTIONS

 --database, -d       database name (required)
 --user, -u           user to create
 --firstname, -f      user's first name
 --lastname, -l       user's last name
 --email, -e          user's email
 --password, -p       password
 --help, -h           this
