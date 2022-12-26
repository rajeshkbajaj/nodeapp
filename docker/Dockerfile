FROM node:12-alpine

# Create app directory
RUN  mkdir /app
WORKDIR /app

# Install app dependencies i.e both package.json AND package-lock.json are copied
COPY package.json /app

RUN npm install

# Copy the app source
COPY server.js /app
COPY . .

EXPOSE 8080

CMD [ "npm" , "start" ]