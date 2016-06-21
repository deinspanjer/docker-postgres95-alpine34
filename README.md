# docker-postgres95-alpine34
A Docker build based on the official postgres but using alpine 3.4 to reduce size.

See the official [docker-library for postgres docs][1] for usage readme and [their original Dockerfile][2] for more details.

== Dockerfile ==
The package installation portion is much simpler than the debian based one found in the official Postgres version.  After installing packages, it performs the other actions similar to the offical image.

== docker-entrypoint.sh ==
The entrypoint script is also very similar to the official image.  Changes of interest are:
* Uses su-exec instead of gosu since su-exec is available as a package in Alpine
* Checks for the existance of /postgresql.conf and if found, replaces the default one in the PGDATA directory with it.


[1]: https://github.com/docker-library/docs/tree/master/postgres
[2]: https://github.com/docker-library/postgres/blob/04b1d366d51a942b88fff6c62943f92c7c38d9b6/9.5/Dockerfile
