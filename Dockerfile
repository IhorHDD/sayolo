FROM nginx
RUN echo "<h1>Hello, World -- from Pulumi!</h1>" > \
    /usr/share/nginx/html/index.html