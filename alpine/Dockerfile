FROM alpine
RUN apk add --no-cache python3 py3-pip ffmpeg socat
RUN pip3 install requests fastapi uvicorn httpx gradio_client pydantic python-multipart --break-system-packages

WORKDIR /data
CMD ["python3", "/data/main.py"]
