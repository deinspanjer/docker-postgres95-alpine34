#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
elif [ "$1" = 'postgres' ]; then
	mkdir -p "$PGDATA"
	chmod 700 "$PGDATA"
	chown -R postgres "$PGDATA"

	chmod g+s /run/postgresql
	chown -R postgres /run/postgresql

	# look specifically for PG_VERSION, as it is expected in the DB dir
	if [ ! -s "$PGDATA/PG_VERSION" ]; then
        : ${POSTGRES_USER:=postgres}

		# check password first so we can output the warning before postgres
		# messes it up
		if [ "$POSTGRES_PASSWORD" ]; then
            echo "$POSTGRES_PASSWORD" > /tmp/.pwfile
            PWFILEARG="--pwfile=/tmp/.pwfile"
            echo "*:*:*:$POSTGRES_USER:$POSTGRES_PASSWORD" > ~/.pgpass
            chmod 600 ~/.pgpass
		else
			# The - option suppresses leading tabs but *not* spaces. :)
			cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for the database.
				         This will allow anyone with access to the
				         Postgres port to access your database. In
				         Docker's default configuration, this is
				         effectively any other container on the same
				         system.

				         Use "-e POSTGRES_PASSWORD=password" to set
				         it in "docker run".
				****************************************************
			EOWARN
		fi

		eval "su-exec postgres initdb $PWFILEARG $POSTGRES_INITDB_ARGS"

        #host    all             all             127.0.0.1/32            md5
        sed -rni "p; s/^(host +all +all +)127\.0\.0\.1\/32(.*)$/\1  0.0.0.0\/0 \2/p" "$PGDATA/pg_hba.conf"

		# internal start of server in order to allow set-up using psql-client		
		# does not listen on external TCP/IP and waits until start finishes
		su-exec postgres pg_ctl -D "$PGDATA" \
			-o "-c listen_addresses='localhost'" \
			-w start

		: ${POSTGRES_USER:=postgres}
		: ${POSTGRES_DB:=$POSTGRES_USER}
		export POSTGRES_USER POSTGRES_DB

		psql=( psql -v ON_ERROR_STOP=1 )

		if [ "$POSTGRES_DB" != 'postgres' ]; then
			"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
				CREATE DATABASE "$POSTGRES_DB" ;
			EOSQL
			echo
		fi

		psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)     echo "$0: running $f"; . "$f" ;;
				*.sql)    echo "$0: running $f"; "${psql[@]}" < "$f"; echo ;;
				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
				*)        echo "$0: ignoring $f" ;;
			esac
			echo
		done

		su-exec postgres pg_ctl -D "$PGDATA" -m fast -w stop

        { echo; echo "include_if_exists = '/etc/postgresql/postgresql.conf'"; } >> "$PGDATA/postgresql.conf"

		echo
		echo 'PostgreSQL init process complete; ready for start up.'
		echo
	fi

	exec su-exec postgres "$@"
else
    echo 'Running as a data volume container.  To persist the data in a host directory, run with --volume <hostdir>:/var/lib/postgresql/data'

	set -- /bin/true
fi

exec "$@"
