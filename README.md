# automated-instance-setup
Scripts used to set up the lightsail instance

## Usage

### Launch Script

- Copy and paste this code when creating the Lighstail instance
:warning: Must be run as root (launch scripts are automatically run as root, but if you're entering into a shell of a pre-existing instance, run `sudo su` first)

| :warning: Make sure you replace **www.DOMAIN.com** with your domain  |
| --- |
```bash
 curl https://raw.githubusercontent.com/nativerank/automated-instance-setup/master/launch.sh | bash -s -- --site-url=www.DOMAIN.com
```

### Setup Script

| :warning: Typically you will not need to run this script manually, turning off development mode in the NR plugin on a new instance will prompt you to run it through the plugin  |
| --- |

- Copy and Paste this code and wait for the success message.

| :warning: Make sure you replace **DB_PASSWORD** with the server's DB password  |
| --- |
```bash
 curl https://raw.githubusercontent.com/nativerank/automated-instance-setup/master/setup.sh | bash -s -- --password=DB_PASSWORD
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
