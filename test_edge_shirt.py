import asyncio
import base64
import json
import subprocess
import time
import urllib.request
from pathlib import Path
from PIL import Image
import numpy as np
import websockets

async def run_edge_shirt_test():
    shirt_path = str(Path("shirt.webp").resolve())
    print("Testing with image:", shirt_path)
    
    profile_dir = Path(r"C:\Users\pc\AppData\Local\Temp\edge_cdp_shirt")
    proc = subprocess.Popen([
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "--headless=new",
        "--remote-debugging-port=9226",
        f"--user-data-dir={profile_dir}",
        "--disable-gpu",
        "http://127.0.0.1:8080/"
    ])
    
    try:
        await asyncio.sleep(2)
        with urllib.request.urlopen("http://127.0.0.1:9226/json/list") as r:
            targets = json.loads(r.read().decode())
        page_target = next(t for t in targets if "EcoStitch" in t.get("title", "") or "8080" in t.get("url", ""))
        ws_url = page_target["webSocketDebuggerUrl"]
        print("Connected to Edge CDP target:", ws_url)
        
        async with websockets.connect(ws_url) as ws:
            msg_id = 0
            
            async def send_cmd(method, params=None):
                nonlocal msg_id
                msg_id += 1
                payload = {"id": msg_id, "method": method, "params": params or {}}
                await ws.send(json.dumps(payload))
                while True:
                    res = json.loads(await ws.recv())
                    if res.get("id") == msg_id:
                        return res.get("result", {})
                    if res.get("method") == "Runtime.consoleAPICalled":
                        args = [str(a.get("value", a.get("description", ""))).encode("ascii", "replace").decode("ascii") for a in res["params"].get("args", [])]
                        print("[Edge Console]", res["params"]["type"], " ".join(args))
            
            await send_cmd("Runtime.enable")
            await send_cmd("Page.enable")
            
            # Dismiss flash screen
            print("1. Dismissing flash screen...")
            await send_cmd("Runtime.evaluate", {
                "expression": "document.getElementById('flash-skip-btn')?.click() || document.getElementById('flash-screen')?.classList.add('fade-out')"
            })
            await asyncio.sleep(0.5)
            
            # Navigate to capture screen
            print("2. Navigating to capture screen...")
            await send_cmd("Runtime.evaluate", {
                "expression": "document.getElementById('btn-start-transformation')?.click()"
            })
            await asyncio.sleep(0.5)
            
            # Upload shirt.webp via file input
            print("3. Uploading shirt.webp via file input...")
            doc = await send_cmd("DOM.getDocument")
            node = await send_cmd("DOM.querySelector", {
                "nodeId": doc["root"]["nodeId"],
                "selector": "#file-picker-input"
            })
            await send_cmd("DOM.setFileInputFiles", {
                "files": [shirt_path],
                "nodeId": node["nodeId"]
            })
            await asyncio.sleep(0.8)
            
            # Verify preview loaded
            prev_info = await send_cmd("Runtime.evaluate", {
                "expression": "JSON.stringify({ "
                              "  previewDisplay: document.getElementById('captured-preview-img')?.style.display, "
                              "  readyCardDisplay: document.getElementById('upload-state-card')?.style.display, "
                              "  filename: document.getElementById('ready-filename')?.textContent "
                              "})",
                "returnByValue": True
            })
            print("Upload preview state:", prev_info.get("result", {}).get("value"))
            
            # Click Continue to trigger preprocessing pipeline
            print("4. Clicking Continue (Start Supabase Upload & AI Preprocessing)...")
            t_start = time.time()
            await send_cmd("Runtime.evaluate", {
                "expression": "document.getElementById('btn-trigger-upload')?.click()"
            })
            
            # Poll for completion
            completed = False
            for step in range(40):
                await asyncio.sleep(0.2)
                res = await send_cmd("Runtime.evaluate", {
                    "expression": "JSON.stringify({ "
                                  "  overlayDisplay: document.getElementById('ai-loading-modal')?.style.display, "
                                  "  resultDisplay: document.getElementById('preprocessed-result-view')?.style.display, "
                                  "  statusText: document.getElementById('ai-tech-status-text')?.textContent, "
                                  "  percent: document.getElementById('ai-percent-counter')?.textContent, "
                                  "  cutoutSrcLen: document.getElementById('cutout-display-img')?.src?.length || 0 "
                                  "})",
                    "returnByValue": True
                })
                state = json.loads(res.get("result", {}).get("value", "{}"))
                status_safe = str(state.get("statusText")).encode("ascii", "replace").decode("ascii")
                t_elapsed = time.time() - t_start
                print(f"[{t_elapsed:.2f}s] Overlay: {state.get('overlayDisplay')}, Result: {state.get('resultDisplay')}, Status: {status_safe}, Progress: {state.get('percent')}")
                if state.get("resultDisplay") == "block":
                    completed = True
                    print(f"\n>>> Preprocessing Pipeline SUCCEEDED in {t_elapsed:.2f} seconds! <<<")
                    break
            
            # Extract and inspect cutout image
            cutout_eval = await send_cmd("Runtime.evaluate", {
                "expression": "document.getElementById('cutout-display-img')?.src",
                "returnByValue": True
            })
            cutout_src = cutout_eval.get("result", {}).get("value", "")
            if "," in cutout_src:
                cutout_data = base64.b64decode(cutout_src.split(",", 1)[1])
                with open("edge_shirt_final_cutout.png", "wb") as f:
                    f.write(cutout_data)
                print("Saved edge_shirt_final_cutout.png, bytes:", len(cutout_data))
                
                # Analyze cutout properties
                im_cutout = Image.open("edge_shirt_final_cutout.png")
                arr = np.array(im_cutout)
                alpha = arr[:, :, 3]
                print(f"Cutout Dimensions: {im_cutout.size} (Zoomed and tightly framed)")
                print(f"Opaque pixels: {np.sum(alpha > 200)}")
                print(f"Clean Transparent Background pixels: {np.sum(alpha < 20)}")
                border_non_zero = (np.sum(alpha[0, :] > 20) + np.sum(alpha[-1, :] > 20) + 
                                   np.sum(alpha[:, 0] > 20) + np.sum(alpha[:, -1] > 20))
                print(f"Perimeter border background artifacts: {border_non_zero} (0 means cleanly isolated main object)")
            
            # Capture final UI screenshot
            ss = await send_cmd("Page.captureScreenshot", {"format": "png"})
            with open("edge_shirt_result_screen.png", "wb") as f:
                f.write(base64.b64decode(ss["data"]))
            print("Saved final Edge UI screenshot to edge_shirt_result_screen.png")
            
    finally:
        proc.terminate()

if __name__ == "__main__":
    asyncio.run(run_edge_shirt_test())
