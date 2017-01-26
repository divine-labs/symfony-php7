## What is this?
This is a docker container running nginx + php-fpm. It is configured towards running a Symfony2 project. Just link a symfony2 project at `/app` and see it yourself!

**Enabled PHP extensions**
* opcache
* pdo_mysql
* intl
* mbstring
* xdebug
* apcu
* gd


It also includes **wkhtmltox** (http://wkhtmltopdf.org/)!


## Usage

Run the following command and go to `<docker-ip>:8080`:
```sh
docker run --name symfony-app -d -v "$(pwd):/app" -p 8080:80 divinelabs/symfony-php7
```
