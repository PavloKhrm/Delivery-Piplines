FROM nginx:1.27-alpine

# copy static assets
COPY public/ /usr/share/nginx/html/

# nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
