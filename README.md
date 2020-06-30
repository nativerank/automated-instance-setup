# automated-instance-setup
Scripts used to set up the lightsail instance

## Usage

### Launch Script

- Copy and paste this code when creating the Lighstail instance

| :warning: Make sure you replace **www.DOMAIN.com** with your domain  |
| --- |
```bash
 curl https://raw.githubusercontent.com/nativerank/automated-instance-setup/master/launch.sh | bash -s -- --site-url=www.DOMAIN.com
```

### Setup Script

- Copy and Paste this code and wait for the success message.

| --- |
```bash
 curl https://raw.githubusercontent.com/nativerank/automated-instance-setup/master/setup.sh | bash -s --
```

### Additional options
| option | description |
| --------|:-----------:|
| --site-url=www.DOMAIN.com | :warning: Make sure you replace **www.DOMAIN.com** with your domain
| --dev-site=DEVSITE-SLUG | replace DEVSITE-SLUG with devsite slug to override the value from wp options |
| --skip-pagespeed | do not optimize pagespeed config file |
| --skip-redis | do not install redis-server |


## Development

### Code Of Conduct

- Only use dist.sh for production build
- For beta testing, either create a new branch or create a beta-VERSION.sh file in master branch
- Feel free to create scratch-VERSION.sh files
