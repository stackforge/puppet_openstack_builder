# notes

As I went through the process of reimplementing kickstack using this
model, I learned the following:

I assumed that all class parameters would mapping to a single piece of hiera
data. This was not entirely correct.

# Issue 1

some data values map to multiple combined values:

   ex: mysql\_connection => db\_name, password, host, user, type

## solutions

1. accept sql\_connection from hiera for each service

This is problematic b/c it will lead to data suplication, and not take advantage of
reasonable defaults

2. patch the components to accept the parts of the password and not the whole thing

That may not be the only occurrence.

It will have to be done in a backwards compat way

3. allow the value of the lookup to be resolvable as multiple lookups (and not a single one)

# Issue number 2

Some data effects the static values of what needs to be passed to other services

Ex: depending on the rpc\_type, the actual rpc\_backend passed to cinder is differnet.

## solutions

1. add an extra parameter called rpc\_type to the class interfaces

2. add rpc\_type to the global data that drives configuration, and make it a variable
that drives the hierarchical configuration

# Issue 3

There is no way to have hiera drive whether or not individual components need to be installed

For now, this will need to be stored as global data that contains a list of the services that
you want to install

# Issue 4

where do we set assumed defaults?

examples:
  - cinder simple scheduler
  - charset for database (can we just set this as a default for the database?)
