# Licensed under the Apache License, Version 2.0 (see LICENSE.md)

# Usage with postgres:
# docker run --name djangocms_db -e POSTGRES_PASSWORD=the_db_password -d postgres
# docker run -d --link djangocms_db:djangocms_db -e MODE="production" -p 8280:80 -p 8200:8000 --name=django-cms-uwsgi-nginx local/django-cms-uwsgi-nginx

# The Django-CMS site will be installed in /cms/website1

FROM python:2.7
# Using python 2.7, because aldryn-people and aldryn-newsblog have a dependency problem with python 3
#    - https://github.com/aldryn/aldryn-people/issues/28

ENV LANG C.UTF-8
# Force stdin, stdout and stderr to be totally unbuffered. 
ENV PYTHONUNBUFFERED 1
ENV PIP_REQUIRE_VIRTUALENV false
# for nano editor etc.
ENV TERM xterm

# Django-CMS Installer defaults, that can be overridden with 'docker run -e ...'
ENV ADMIN_USER admin
ENV ADMIN_EMAIL admin@example.com
ENV ADMIN_PASSWD django-cms
ENV MODE production

# Install nginx and a few utilities
RUN echo "deb http://http.debian.net/debian jessie-backports main" >> /etc/apt/sources.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
        nano \
        patch \
        unzip \
        zip && \
    DEBIAN_FRONTEND=noninteractive apt-get -y -t jessie-backports install \
        nginx && \
    apt-get clean && rm -r /var/lib/apt/lists/*

# Django-CMS with plugins, UWSGI & Supervisor
COPY ./requirements.txt /cms/requirements.txt
RUN pip install -r /cms/requirements.txt

# setup the config files
# forward request and error logs to supervisor logs
COPY ./config/ /cms/config/
RUN echo "daemon off;" >> /etc/nginx/nginx.conf && \
    rm -v /etc/nginx/sites-enabled/default && \
    ln -sv /cms/config/nginx-djangocms.conf /etc/nginx/sites-enabled/ && \
    ln -svf /dev/stdout /var/log/nginx/access.log && \
    ln -svf /dev/stderr /var/log/nginx/error.log && \
    mkdir -pv /var/log/supervisor/

# Persist site & user data
VOLUME [ "/cms" ]

EXPOSE 80 8000
WORKDIR /cms

COPY docker-entrypoint /docker-entrypoint

# Install Django-CMS on first-run of container
ENTRYPOINT ["/docker-entrypoint"]

# specifying an absolute path to config file for improved security & to avoid supervisord warning
CMD ["supervisord", "-n", "-c", "/cms/config/supervisord.conf"]
