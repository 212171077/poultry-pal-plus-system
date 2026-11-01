# syntax=docker/dockerfile:1

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npx ng build --configuration production

FROM nginx:1.27-alpine
ENV TLS_ENABLED=true TLS_SERVER_NAME=tertiaryverify.dedicated.co.za
# Unprivileged port; see nginx.conf.template.
EXPOSE 8080
COPY nginx.conf.template /opt/poultry-pal/nginx.conf.template
COPY scripts/configure-tls.sh /docker-entrypoint.d/40-configure-tls.sh
RUN chmod +x /docker-entrypoint.d/40-configure-tls.sh
COPY --from=build /app/dist/poultry-pal-plus-web/browser /usr/share/nginx/html
