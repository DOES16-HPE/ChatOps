# DOES-hubot
Dockerized hubot for DOES demo

# How to build
Copy hubot/hubot.env.template to new file hubot/hubot.env and update relevant env variables (ElectricFlow username/password, proxy settings). Once hubot.env place is in place, run the following docker build command

```
docker build -t does-hubot .
```

# How to run
```
docker run -e "HUBOT_FLOWDOCK_API_TOKEN=<API_TOKEN>" -e "REDIS_PASSWORD=<REDIS_PASSWORD>" -p 5602 -v /data/redis -v /log/redis -v /log/supervisor -v /log/hubot --name does-hubot does-hubot
```

# Important files and directories in repo
- hubot : source code for dockerized hubot
- redis : dir with redis config file, update 'requirepass' line in redis.conf to secure redis with pw
- supervisor : dir for supervisor config files

# Hubot specific files and dirs
- hubot/hubot.env : env file that is sourced when hubot runs. Set variables here
- hubot/scripts : contains all hubot scripts
- package.json : Node.js dependencies file
- external-scripts.json : enable external NPM dependencies in this file

# Develop new bot scripts
- Use [CoffeeScript](http://coffeescript.org/) language to write hubot scripts (make sure all of your scripts end in .coffee)
- Make sure to include all external NPM dependencies in the package.json file
- Place all newly developed scripts in the hubot/scripts directory
- Once new script is developed, rebuild docker image to test and deploy
- To know what bot commands are supported by hubot, run 'bot name' help
- Visit GitHub's bot documentation for an in-depth tutorial on hubot scripting - https://hubot.github.com/docs/scripting/
