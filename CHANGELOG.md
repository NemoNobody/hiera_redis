# Changelog

All notable changes to this project will be documented in this file.

## Release 0.3.0 

** Bugfixes **

* Added `redis.close()` action for closing redis connection, without this, we probably will have issues with free TCP sockets on puppetserver

** Features **

* Added timeouts to redis connections, also added options to configure it, see more in README. by default all timeouts 0.5 seconds(read,write,connect).


## Release 0.2.0


** Bugfixes**

* If we will find `{` and `}` in result from redis, we will need to make it hash - this part always recieve `{}` e.g. empty hash. - For now we use json for make hash from string, if it is posable
* Interpolation not working - for now if result from redis has some what puppet can interpolate(get value from hiera), e.g. some like `%{hiera('somekey')}`, it is will be replaced by `somekey` value




## Release 0.1.0

**Features**

* added condition for detect hash in data into redis key and change result type to HASH type for puppet.

**Bugfixes**

**Known Issues**
