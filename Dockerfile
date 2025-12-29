########################################################################
FROM bedrock-debian AS builder
########################################################################

ENV PERL_CPANM_OPT="--mirror-only --mirror https://cpan.openbedrock.net/orepan2 --mirror https://cpan.metacpan.org"

RUN apt-get update && apt-get install -y make gcc curl ca-certificates sqlite3 libsqlite3-dev

COPY BLM-Startup-SQLiteSession*.tar.gz /

RUN curl -L https://cpanmin.us | perl - App::cpanminus

RUN cpanm -v -n -l /usr/src/app/local /BLM-Startup-SQLiteSession*.tar.gz

########################################################################
FROM bedrock-debian
########################################################################
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=builder /usr/src/app/local /usr/src/app/local

RUN apt-get update && apt-get install -y perl-doc vim less sqlite3
RUN BLM_STARTUP_SQLITESESSION_DIST_DIR=$(perl -MFile::ShareDir=dist_dir -e 'print dist_dir("BLM-Startup-SQLiteSession");'); \
    cp $BLM_STARTUP_SQLITESESSION_DIST_DIR/sqlite.xml /var/www/bedrock/config.d/startup
RUN rm -r /var/www/bedrock/config.d/startup/mysql-session.xml
RUN /usr/src/app/local/bin/bedrock-sqlite.pl -d /var/lib/bedrock/bedrock.db -o www-data

ENV BEDROCK_SESSION_MANAGER='SQLiteSession'

ENV PATH=/usr/src/app/local/bin:$PATH
