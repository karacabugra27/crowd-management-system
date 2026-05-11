import os
import subprocess
import time
import requests
import argparse
from datetime import datetime

# API Base URL
API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000")

def get_real_wifi_device_count():
    """Uses ARP to count real devices connected to the same network."""
    try:
        # Run arp -a to get local network devices
        result = subprocess.check_output("arp -a", shell=True).decode("utf-8", errors="ignore")
        count = 0
        # Count lines that contain 'dynamic' or 'dinamik'
        for line in result.split("\n"):
            if "dynamic" in line.lower() or "dinamik" in line.lower():
                count += 1
        return count
    except Exception as e:
        print(f"Error reading ARP table: {e}")
        return 0

def collect_and_send(area_id: str):
    # Ağda gerçekten bağlı olan cihazları say:
    real_count = get_real_wifi_device_count()
    
    # Not: Telefon hotspot'una bağlandığınızda kendi IP'nizi ve varsa router'ı çıkarabiliriz 
    # Ancak test için direkt dinamik cihaz sayısını yolluyoruz.
    # Hotspot'a bilgisayardan ek bağlanan her yeni telefon bu sayıyı artıracaktır.
    
    payloads = [
        {"area_id": area_id, "device_count": real_count}
    ]
    
    try:
        response = requests.post(f"{API_BASE_URL}/occupancy/ingest/bulk", json=payloads, timeout=10)
        response.raise_for_status()
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ✅ Gerçek Veri Gönderildi: Alan={area_id}, Cihaz={real_count}")
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Veri gönderilemedi: {e}")

def main():
    parser = argparse.ArgumentParser(description="Real Wi-Fi Scanner")
    parser.add_argument("--area", type=str, required=True, choices=["library", "cafeteria"], 
                        help="Hangi alanı taradığınızı seçin (library veya cafeteria)")
    args = parser.parse_args()

    print("="*50)
    print(f"🚀 Wi-Fi Tarayıcı Başlatıldı (Taranan Alan: {args.area.upper()})")
    print("="*50)
    
    while True:
        collect_and_send(args.area)
        time.sleep(5) # Daha hızlı test edebilmeniz için 5 saniyeye çektim

if __name__ == "__main__":
    main()
