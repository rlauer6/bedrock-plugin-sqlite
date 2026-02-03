#!/usr/bin/env perl

# Utility for use with BLM::Startup::SQLiteSession

package Bedrock::SQLite::Session;

use strict;
use warnings;

use BLM::Startup::SQLiteSession qw(create_encrypt_function);
use CLI::Simple::Constants qw(:booleans);
use Carp;
use DBI;
use Data::Dumper;
use English qw(-no_match_vars);
use File::Basename qw(dirname fileparse);
use File::Path qw(make_path);
use File::ShareDir qw(dist_dir);
use List::Util qw(any);
use JSON;

use parent qw(CLI::Simple);

########################################################################
sub _connect {
########################################################################
  my ($self) = @_;

  my $database = $self->get_database;

  my $dsn = sprintf 'dbi:SQLite:dbname=%s', $database;

  my $dbi = DBI->connect( $dsn, undef, undef, { RaiseError => $TRUE, PrintError => $FALSE } );

  return $dbi;
}

########################################################################
sub cmd_create_database {
########################################################################
  my ($self) = @_;

  my $database = $self->get_database;

  if ( -e $database ) {
    croak "Database $database already exists. Use --force to recreate\n"
      if !$self->get_force;

    unlink $database;
  }

  my $dir = dirname($database);

  my $owner = $self->get_owner;

  if ( !-d $dir ) {
    croak 'ERROR: could not create ' . $dir
      if !make_path( $dir, $owner ? { owner => $owner, group => $owner } : () );
  }

  my $sql = eval {
    local $RS = undef;

    open my $fh, '<', sprintf '%s/%s', $self->get_dist_dir, 'create-session-table.sql'
      or croak 'ERROR: could not open create-session-table.sql';

    my $sql = <$fh>;
    close $fh;

    return $sql;
  };

  croak "ERROR: Could not read create-session-table.sql\n$EVAL_ERROR"
    if !$sql;

  eval {
    my $dbi = $self->_connect;

    $dbi->do($sql);

    if ($owner) {
      my $gid = ( getgrnam $owner )[2];
      my $uid = ( getpwnam $owner )[2];

      chown $uid, $gid, $database;
    }

    create_encrypt_function($dbi);

    $dbi->disconnect;
  };

  croak "ERROR: failed to create database $database\n$EVAL_ERROR\n"
    if !-e $database || $EVAL_ERROR;

  return 0;
}

########################################################################
sub cmd_dump {
########################################################################
  my ($self) = @_;

  my $dbi = $self->_connect;

  my $sql = <<'END_OF_SQL';
SELECT * FROM session
END_OF_SQL
  my $result = $dbi->selectall_arrayref($sql);

  print {*STDERR} JSON->new->pretty->encode($result);

  $dbi->disconnect;

  return 0;
}

########################################################################
sub cmd_create_user {
########################################################################
  my ($self) = @_;

  my $dbi = $self->_connect;

  my $user     = $self->get_user;
  my $password = $self->get_password;

  return
    if !$user || !$password;

  my $sql = <<'END_OF_SQL';
INSERT INTO session 
(username, password, firstname, lastname, email)
  VALUES
( ?, encrypt(?), ?, ?, ? )
END_OF_SQL

  my @bind_args = ( $user, $password, $self->get_firstname, $self->get_lastname, $self->get_email );

  eval { return $dbi->prepare($sql)->execute(@bind_args); };

  if ( $EVAL_ERROR && $EVAL_ERROR =~ /unique\sconstraint\sfailed/ixsm ) {

    croak 'ERROR: To update a user, pass all options'
      if any { !defined $_ } ( $user, $password, $self->get_firstname, $self->get_lastname, $self->get_email );

    my $update_sql = <<'END_OF_SQL';
UPDATE session 
  SET username = ?,
      password = encrypt(?),
      firstname = ?,
      lastname = ?,
      email = ?
  WHERE username = ?
END_OF_SQL

    my $sth = $dbi->prepare($update_sql);
    $sth->execute( @bind_args, $user );
  }

  return 0;
}

########################################################################
sub init {
########################################################################
  my ($self) = @_;

  my $path = dist_dir('BLM-Startup-SQLiteSession');

  croak 'ERROR: Unable to find distribution path'
    if !$path;

  $self->set_dist_dir($path);

  croak 'ERROR: --database is a required argument'
    if !$self->get_database;

  return;
}

########################################################################
sub main {
########################################################################
  my @option_specs = qw(
    help|h
    database|d=s
    user|u=s
    password|p=s
    firstname|f=s
    lastname|l=s
    email|e=s
    force|f
    owner|o=s
  );

  my %commands = (
    default => \&cmd_create_database,
    create  => \&cmd_create_database,
    user    => \&cmd_create_user,
    dump    => \&cmd_dump,
    alias   => {
      commands => {
        'dump-session'   => 'dump',
        'create-session' => 'create',
        'add-user'       => 'add',
      }
    },
  );

  my $cli = Bedrock::SQLite::Session->new(
    option_specs    => \@option_specs,
    commands        => \%commands,
    extra_options   => [qw(dist_dir)],
    default_options => { database => '/var/lib/bedrock/bedrock.db' },
  );

  return $cli->run();
}

exit main();

1;

__END__

=pod

=head1 USAGE

 bedrock-sqlite.pl --database database-name [--user user --password password --help]

Creates a session table for storing persistent Bedrock sessions.
Optionally creates a login user. If you want to create or update a user, C<--user>
and C<--password> are required arguments.

=head2 Options

 --database, -d       database name (required)
 --user, -u           user to create
 --firstname, -f      user's first name
 --lastname, -l       user's last name
 --email, -e          user's email
 --password, -p       password
 --force, -f          force recreation of database
 --owner, -o          set owner/group for database
 --help, -h           this

=head2 Example

 bedrock-sqlite -d /var/lib/bedrock/bedrock.db create

bedrock-sqlite -d /var/lib/bedrock/bedrock.db -u fred -p 'Bedr0ck!' \
  -e 'fflintstone@openbedrock.org' add-user

=cut
