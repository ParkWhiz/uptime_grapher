# uptime_grapher
Uses Pingdom API to graph weekly uptime of services

## Setup

First, create a `.env` file and modify it to fit your creditials:

```
cp .env.example .env
```

Then, install the Ruby environment

```
bundle install
```

On OSX, you may have to install ghostscript:

```
brew install gs
```

## Usage

see
```
./uptime-grapher.rb --help
```

## Adjusting for scheduled downtime

You can remove scheduled downtime from the graph by specifying a yaml file
and using the `-s` flag. the yaml file should be of the format:

```

yyyy-mm-dd:
  check name 1: minutes-of-downtime
  check name 2: minutes-of-downtime
  ...
yyyy-mm-dd:
  check name 1: minutes-of-downtime
  check name 2: minutes-of-downtime
  ...

```

For example:

```

2016-11-17:
  Parkwhiz: 13
  API v2: 13
  API v3: 13
  Affiliate API: 13
  Quote from v3: 13
  Admin and Seller Console: 13

```
