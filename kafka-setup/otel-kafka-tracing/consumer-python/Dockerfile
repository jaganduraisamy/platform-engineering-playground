FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org \
    'setuptools<70' \
    -r requirements.txt
COPY consumer.py ./

CMD ["opentelemetry-instrument", "python", "consumer.py"]
