# PUBLIC

BLM::Startup::SQLiteSession - Bedrock sessions using SQLite

# SYNOPSIS

- 1. Add a configuration object in Bedrock's startup configuration
path (typically `/var/www/bedrock/config.d/startup`):

        <object>
          <scalar name="binding">session</scalar>
          <scalar name="session">yes</scalar>
          <scalar name="module">BLM::Startup::SQLiteSession</scalar>
          <object name="config">
            <scalar name="data_source">dbi:SQLite:dbname=/var/lib/bedrock/bedrock.db</scalar>
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

- 2. Create a SQLite database

        sqlite3 /tmp/bedrock.db

- 3. Create a session table

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

    _Note: You can also use the included `bedrock-sqlite.pl` script._

        bedrock-sqlite.pl -d /var/lib/bedrock/bedrock.db -o www-data create

- 4. Restart Apache
- 5. Test your session
    - An anonymous session...

            <pre><trace --output $session></pre>

    - Register a user...

            <null $session.register('fflintstone', 'P3881e$', 'Fred', 'Flintstone', 'fflintstone@openbedrock.org')>

    - Login a user...

            <null $session.login($input.username, $input.password)>

    - Persist some data to your session...

            <null $session.set('foo', 'bar')>
            <null $session.set('input', $input)>

# DESCRIPTION

Class to provide the implementation for a SQLite based session manager.

Generally speaking, a SQLite based session manager is probably not
appropriate for a production environment, however when doing local
development, a SQLite session manager works well. You can start doing
local development with session management included by just installing
this plugin and following the steps in the ["SYNOPSIS"](#synopsis). No need to
rely on a database server to provide session manager.

# SEE ALSO

[BLM::Startup::SessionManager](https://metacpan.org/pod/BLM%3A%3AStartup%3A%3ASessionManager)

# AUTHOR

Rob Lauer - <bigfoot@cpan.org>
