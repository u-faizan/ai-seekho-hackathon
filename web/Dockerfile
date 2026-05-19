# Use a lightweight Nginx image
FROM nginx:alpine

# Copy static assets to Nginx html directory
COPY . /usr/share/nginx/html/

# Expose port 80 (standard Nginx port)
EXPOSE 80

# Run Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
