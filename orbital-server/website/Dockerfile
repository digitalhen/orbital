FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/orbital/index.html
COPY icon.png /usr/share/nginx/html/orbital/icon.png
COPY install.sh /usr/share/nginx/html/orbital/install.sh
COPY hero.png /usr/share/nginx/html/orbital/hero.png
COPY privacy.html /usr/share/nginx/html/orbital/privacy.html
COPY appcast.xml /usr/share/nginx/html/orbital/appcast.xml
RUN mkdir -p /usr/share/nginx/html/orbital/downloads && \
    wget -q -O /usr/share/nginx/html/orbital/downloads/Orbital-1.2.dmg \
    "https://github.com/digitalhen/orbital/releases/download/v1.2-build5/Orbital-1.2.dmg"
