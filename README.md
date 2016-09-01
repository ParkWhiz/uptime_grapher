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

```
./uptime-grapher.rb
```
