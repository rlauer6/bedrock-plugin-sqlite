package BLM::Startup::SQLiteSession;

#
#    This file is a part of Bedrock, a server-side web scripting tool.
#    Check out http://www.openbedrock.net
#    Copyright (C) 2024, TBC Development Group, LLC.
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

use strict;
use warnings;

use POSIX qw(strftime);
use Data::Dumper;
use Digest::SHA qw(sha256_hex);

use BLM::Startup::SQLSession qw($DUPLICATE_USERNAME $USERNAME_NOT_FOUND $BAD_LOGIN);

use parent qw( Exporter BLM::Startup::SQLSession );

our @EXPORT_OK = qw(create_encrypt_function);

our $VERSION = '1.0.1';

########################################################################
sub create_encrypt_function {
########################################################################
  my ($dbi) = @_;

  $dbi->sqlite_create_function(
    'encrypt',
    -1,
    sub {
      my ( $password, $salt ) = @_;

      $salt //= join q{}, ( '0' .. '9', 'a' .. 'f' )[ map { int rand 16 } ( 0 .. 7 ) ];

      my $encrypted_password = $salt . sha256_hex( $salt . $password );

      return $encrypted_password;
    }
  );

  return;
}

########################################################################
sub CONNECT {
########################################################################
  my ( $self, %args ) = @_;

  $args{config}->{host} = q{};  # indicate we have no host

  $self->SUPER::CONNECT(%args);

  create_encrypt_function( $self->{dbh} );

  return;
}

########################################################################
sub LOGIN {
########################################################################
  my ( $self, %options ) = @_;

  my ( $username, $password ) = @options{qw(username password)};

  my $aref = $self->do_select( 'LOGIN', %options );

  #  print {*STDERR} Dumper( [ aref => $aref ] );

  die sprintf $BAD_LOGIN, $options{username}
    if !defined $aref;

  my $encrypted_password  = $aref->[5];
  my ($salt)              = substr $encrypted_password, 0, 8;
  my $calculated_password = $salt . sha256_hex( $salt . $options{password} );

  #  print {*STDERR} Dumper(
  #    [ salt                => $salt,
  #      encrypted_password  => $encrypted_password,
  #      calculated_password => $calculated_password,
  #      password            => $options{password},
  #    ]
  #  );

  die sprintf $BAD_LOGIN, $options{username}
    if $calculated_password ne $encrypted_password;

  return $aref;
}

%BLM::Startup::SQLSession::SQL = (
  FETCH_LOGIN_SESSION => {
    sql => q{
      select username, firstname, lastname, email, prefs 
      from %s 
      where login_cookie = ? 
    },
    args => ['login_id']
  },
  FETCH_SESSION => {
    sql => q{
      select username, firstname, lastname, email, prefs 
      from %s 
      where session = ? and expires > datetime('now')
    },
    args => ['session']
  },
  KILL_SESSION => {
    sql => q{
      delete
      from %s 
      where session = ?
    },
    args => ['session']
  },
  LOGIN => {
    sql => q{
      select username, firstname, lastname, email, prefs, password 
      from %s 
      where username = ?
    },
    args => [qw(username)]
  },
  LOGOUT_ANON => {
    sql => q{
      update %s
      set expires = datetime('now')
      where session = ?
    },
    args => ['session']
  },
  LOGOUT_USER => {
    sql => q{
      update %s
      set expires = datetime('now')
      where username = ? and session= ?
    },
    args => [ 'username', 'session' ]
  },
  LOOKUP_USER => {
    sql => q{
      select username
      from %s
      where username = ?
    },
    args => ['username']
  },
  REGISTER => {
    sql => q{
      insert into %s (username, password, firstname, lastname, email, added)
      values (?, encrypt(?), ?, ?, ?, datetime('now'))
    },
    args => [qw{username password firstname lastname email}]
  },
  REMOVE_USER => {
    sql => q{
      delete from %s 
        where username = ? and
        password = encrypt(?, substr(password, 1, 8))
    },
    args => [qw{username password}]
  },
  LOGIN_SESSION_CLEANUP => {
    sql => q{ 
      update %s set session = '', expires = datetime('now') 
         where expires < datetime('now') and (username <> '' or username is not null)
       },
    args => []
  },
  SESSION_CLEANUP => {
    sql => q{
      delete from %s 
      where expires < datetime('now') and 
      (username = '' or username is null)
    },
    args => []
  },
  STORE_LOGIN_SESSION_BY_USERNAME => {
    sql => q{
      update %s set session = ?, prefs = ?,
      expires = datetime('now', '+' || ? || ' second')
      where username = ?
    },
    args => [qw{session prefs expires username}]
  },
  STORE_LOGIN_SESSION_BY_LOGIN_ID => {
    sql => q{
      update %s set session = ?, expires = datetime('now', '+' || ? || ' second')
      where login_cookie = ?
    },
    args => [qw{session expires login_id}]
  },
  STORE_SESSION_INSERT => {
    sql => q{
      insert into %s (added, session, prefs) values (datetime('now'), ?, ?)
    },
    args => [qw{session prefs}]
  },
  STORE_SESSION_UPDATE => {
    sql => q{
      update %s set expires = datetime('now', '+' || ? || ' second'),
      prefs = ?
      where session = ?
    },
    args => [qw{expires prefs session}]
  },
  UPDATE_LOGIN_PASSWORD => {
    sql => q{
      update %s set password = encrypt(?)
      where username = ? and session = ?
    },
    args => [qw{password username session}]
  },
  UPDATE_SESSION => {
    sql => q{
      update %s set expires = datetime('now', '+' || ? || ' second')
      where session = ?
    },
    args => [qw{expires session}]
  },
  UPDATE_LOGIN_SESSION => {
    sql => q{
      update %s set login_cookie = ?
      where username = ?
    },
    args => [qw{login_id username}]
  }
);

1;

__END__

=pod

=head1 NAME

BLM::Startup::SQLiteSession - Bedrock sessions using SQLite

=head1 SYNOPSIS

=over 5

=item Add a configuration object in Bedrock's startup configuration path:

 <object>
   <scalar name="binding">session</scalar>
   <scalar name="session">yes</scalar>
   <scalar name="module">BLM::Startup::SQLiteSession</scalar>
   <object name="config">
     <scalar name="data_source">dbi:SQLite:dbname=/tmp/bedrock.db</scalar>
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

=item Create a SQLite database

 sqlite3 /tmp/bedrock.db

=item Create a session table

 CREATE TABLE session
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

  CREATE TRIGGER session_updates AFTER UPDATE ON session
    BEGIN
      UPDATE session SET updated=CURRENT_TIMESTAMP where rowid=new.rowid;
    END;

I<Note: You can also use the included C<create-session-table.pl> script.>

=item Restart Apache

=item Test your session

=over 10

=item An anonymous session...

  <pre><trace --output $session></pre>

=item Register a user...

  <null $session.register('fflintstone', 'P3881e$', 'Fred', 'Flintstone', 'fflintstone@openbedrock.org')>

=item Login a user...

 <null $session.login($input.username, $input.password)>

=item Persist some data to your session...

 <null $session.set('foo', 'bar')>
 <null $session.set('input', $input)>

=back

=back

=head1 DESCRIPTION

Class to provide the implementation for a SQLite based session manager.

=head1 SEE ALSO

L<BLM::Startup::SessionManager>

=head1 AUTHOR

Rob Lauer - <bigfoot@cpan.org>

=cut
