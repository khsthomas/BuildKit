FROM nginx:stable-alpine AS nginx-base

EXPOSE 443
WORKDIR /var/www
RUN chown nginx:nginx /var/www

COPY nginx.conf /etc/nginx/nginx.conf
COPY server.conf /etc/nginx/server_block.conf
COPY general_nginx_security_headers.conf /etc/nginx/general_nginx_security_headers.conf
COPY nginx.vh.default.conf /etc/nginx/conf.d/default.conf