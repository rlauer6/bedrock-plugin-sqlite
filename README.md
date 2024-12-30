# NAME

BLM::Startup::SQLiteSession - Bedrock sessions using SQLite

# SYNOPSIS

- Add a configuration object in Bedrock's startup configuration path:

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

- Create a SQLite database

        sqlite3 /tmp/bedrock.db

- Create a session table

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

- Restart Apache
- Test your session

        <pre><trace --output $session></pre>

# DESCRIPTION

Class to provide the implementation for a SQLite based session manager.

# SEE ALSO

[BLM::Startup::SessionManager](https://metacpan.org/pod/BLM%3A%3AStartup%3A%3ASessionManager)
