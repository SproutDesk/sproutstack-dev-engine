# SproutStack Dev Engine

A set of containers to host PHP web applications, along with a few other useful tools, on your local machine.

This was built to handle multiple virtual hosts to make switching between projects a breeze, using defined hostnames instead of just `localhost`, each being able to run their respective PHP versions simultaneously.

## Getting Started

### Prerequisites

* Docker
* Docker Compose
* Git
* Linux/Windows (with WSL2)
* Your user must not be the `root` user & must be a member of the `docker` group

### Installing

Clone this repo to where you want your development environment to be located, e.g. `$HOME/sproutstack/`

```
$ git clone https://github.com/SproutDesk/sproutstack-dev-engine.git $HOME/sproutstack
```

Copy the `.env.example` file to `.env` and modify as needed.

Run `docker-compose up -d` to boot up the default SproutStack dev engine.
>**Note:** first-run it may take a short while as it will need to download the images from the container registry to run each container.*

## Usage

Use your .env file to define true/false values for tools you'd like to enable/disable.
> **Note:** The value of MYSQL_ROOT_PASSWORD is only used on first initialisation of the database volume

Applications should be built within the `workspace/` folder in the project, which is mounted to `/workspace` in the Nginx & PHP containers.
e.g. `/home/myusername/sproutstack/workspace/` on the host would map its path to `/workspace/` within the Nginx & PHP containers

### Creating a new virtualhost/server (Nginx)

//TODO: write about nginx

goto nginx/sites/ & copy an example. Change the server_name, root, and PHP version to what you need.

### Using PHP Extensions

(Optional) To use one of the available extensions, open `.env` in a text editor, assign a value to the `PHP_EXTENSION` variable and reload the PHP containers with a simple `docker-compose down` and `docker-compose up -d`

**Xdebug** is enabled by default unless changed in your `.env` file. Xdebug options can be found in `php/xdebug.ini`.
You can find other Xdebug options available [HERE](https://xdebug.org/docs/all_settings)

**Ioncube loader** be used with Xdebug, hence it being its own version.

**Blackfire** probe is installed to PHP to report back to the local Blackfire agent on port `8707`. If you don't have a Blackfire agent running locally, you can enable the built in agent in your `.env` file

### Database Management (MySQL and PostgreSQL)

phpMyAdmin comes packaged as its own container, accessed via the webserver with the URL `http://phpmyadmin.local/` in your browser or via FastCGI/FPM on port 9306.
Adminer also comes committed to `/workspace/adminer/` to work with either MySQL or PostgreSQL. Accessible under `http://adminer.local/`

### Reverse-Proxy Cache (Varnish)

Varnish cached versions of sites can be viewed under port `:8888`, for example: `http://adminer.local:8888/`

The default VCL file is located under `varnish/default.vcl` and changes can be activated by restarting the Varnish container with `docker-compose restart varnish`

> **Note:** Debug headers are sent with each response, including cache age, grace, and hits

### Email testing (Mailhog/SSMTP)

Each PHP container comes packaged with SSMTP to relay mail to `localhost:1025` (configurable). This by default routes to the MailHog container, which will trap all emails sent by PHP's mail function.

You can view trapped emails in your browser by visiting `http://localhost:8025`

For more info on using MailHog, see [HERE](https://hub.docker.com/r/mailhog/mailhog/)

> **Note:** To direct emails to an external server, you can reconfigure the config here at `php/ssmtp.conf` (no restart needed). See [HERE](https://wiki.archlinux.org/index.php/SSMTP) for config options

### Using Redis

Redis is available to your application at port `6379`. No further setup is required for local development.

## Specification
### Images
* **PHP**: Versions 5.6, 7.0, 7.1, 7.2, 7.3, 7.4
* **Nginx**: Version 1.18
* **MySQL**: Version Configurable in `.env`
* **Varnish**: Version 6.1 (VCL 4.0)
* **Redis**: Version 6.x
* **PHPMyAdmin**: Extended latest image
* **MailHog**: Version 1.0
* **Blackfire Agent**: Version 1.34

### Networking/Ports
Nginx, PHP-FPM, and Varnish are run on the host network, rather than behind the docker bridge.
All other containers are bound to ports through the docker bridge.
#### Ports Used
* **PHP**: 90xx _(9056 for PHP5.6, 9070 for PHP7.0, 9071 for PHP7.1, etc...)_
* **Nginx**: 80 _(HTTP)_ & 443 _(HTTPS - self-signed SSL)_
* **MySQL**: 3306
* **PostgreSQL**: 5432
* **Varnish**: 8888 _(relayed to Nginx on port 80 for the backend)_
* **Redis**: 6379
* **phpMyAdmin**: 9306 _(FastCGI/FPM Listener)_. Default URL: http://phpmyadmin.local
* **MailHog**: 1025 _(SMTP)_ & 8025 _(HTTP GUI)_
* **Blackfire Agent**: 8707

## Roadmap
Short-term goals:
* CLI Tool to semi-automate certain tasks
* DNS resolution handler to automatically register local domains
* Register local SSL certificates to OS trust store

Long-term goals:
* Management via GUI

## Credits

* [**Rhys Botfield**](https://rhysbotfield.co.uk/) - [SproutDesk](https://sproutdesk.co.uk/)
