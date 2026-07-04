FROM alpine
RUN apk add --no-cache python3 py3-pip
RUN pip3 install requests fastapi uvicorn httpx gradio_client pydantic --break-system-packages

WORKDIR /data
CMD ["python3", "/data/main.py"]