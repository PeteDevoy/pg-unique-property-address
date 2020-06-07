This repo is for the benefit of interested parties on the pgsql-general mailing
list.

Set-up (from project directory):

```bash
vagrant up
```

Test (from project directory):

```bash
vagrant ssh
sudo su addresstest
psql -f /vagrant/test.sql
pg_prove --d addresstest --runtests --verbose
```

Or with pretty results with `tap-mocha-reporter` installed:

```bash
pg_prove --d addresstest --runtests --verbose | tap-mocha-reporter classic
```