FROM bedrock-debian

ENV PERL_CPANM_OPT="--mirror-only --mirror https://cpan.openbedrock.net/orepan2 --mirror https://cpan.metacpan.org"

RUN apt-get update && apt-get install -y sqlite3 libsqlite3-dev

# always get the latest version of Bedrock
RUN cpanm -v -n --reinstall Bedrock

RUN cpanm -v -n DBD::SQLite BLM::Startup::SQLiteSession

COPY create-session-table.sql /usr/local/share

RUN rm -r /var/www/bedrock/config.d/startup/mysql-session.xml

COPY sqlite-startup.sh /usr/local/bin

RUN /usr/local/bin/sqlite-startup.sh

ENTRYPOINT ["/usr/local/bin/start-server"]
