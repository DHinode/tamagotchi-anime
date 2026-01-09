import json
import os
from dotenv import load_dotenv
from web3 import Web3

# Load .env variables
load_dotenv()

# === Web3 connection ===
web3 = Web3(Web3.HTTPProvider("https://rpc.blaze.soniclabs.com"))
from_address = os.getenv("PUBLIC_KEY")
private_key = os.getenv("PRIVATE_KEY")

# === Define path to ABI files (relative to this script) ===
script_dir = os.path.dirname(__file__)  # this gets the current script's directory

def load_abi(filename):
    with open(os.path.join(script_dir, filename)) as f:
        return json.load(f)

# === Load ABIs ===
# sm_ABI = load_abi("file_ABI.json")


# === Contract addresses ===
# sm_address = os.getenv("ADDRESS_IN_DOTENV")

# === Contract instances ===
# sm_contract = web3.eth.contract(address=sm_address, abi=sm_ABI)



