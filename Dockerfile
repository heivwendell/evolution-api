FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

LABEL version="2.3.0" description="Api to control whatsapp features through http requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

# Copia arquivos de configuração
COPY ./package.json ./tsconfig.json ./

# ⚠️ Aplica resolução forçada e instala dependências com flags
RUN npx npm-force-resolutions && npm install --legacy-peer-deps

# Copia os demais arquivos do projeto
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./
COPY ./tsup.config.ts ./
COPY ./Docker ./Docker

# Permissões dos scripts do Docker
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# Geração do banco de dados
RUN ./Docker/scripts/generate_database.sh

# Compila
RUN npm run build

# Imagem final
FROM node:20-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
# 🔥 NÃO copiar package-lock.json se ele não existir ou for problema
# Se você tiver excluído do projeto, comente ou remova a linha abaixo:
# COPY --from=builder /evolution/package-lock.json ./package-lock.json

COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

ENV DOCKER_ENV=true

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
