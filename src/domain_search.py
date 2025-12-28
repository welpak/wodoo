import socket
import itertools
import time

# Configuration
KEYWORDS = ["bird", "byrd", "owl"]
TLDS = [".com", ".io", ".xyz"]
SUBSTITUTIONS = {
    "i": ["1"],
    "e": ["3"],
    "o": ["0"],
    "l": ["1"],
    "a": ["4"],
    "s": ["5"],
    "t": ["7"]
}

WHOIS_SERVERS = {
    ".com": "whois.verisign-grs.com",
    ".io": "whois.nic.io",
    ".xyz": "whois.nic.xyz"
}

def generate_leet_variations(word):
    """
    Generates all leet speak variations for a given word.
    """
    options = []
    for char in word:
        chars = [char]
        if char.lower() in SUBSTITUTIONS:
            chars.extend(SUBSTITUTIONS[char.lower()])
        options.append(chars)

    variations = set()
    for combo in itertools.product(*options):
        variations.add("".join(combo))
    return list(variations)

def generate_candidates():
    """
    Generates a list of domain candidates.
    """
    candidates = set()

    for keyword in KEYWORDS:
        candidates.add(keyword)
        candidates.update(generate_leet_variations(keyword))

        # Phonetic / Shortened / Extended
        if keyword == "bird":
            candidates.add("brd")
            candidates.add("burd")
            candidates.add("birdd")
            candidates.add("byrds")
        if keyword == "byrd":
            candidates.add("byrdd")
            candidates.add("byrds")
        if keyword == "owl":
            candidates.add("owel")
            candidates.add("owls")
            candidates.add("owll")

    domain_list = []
    for name in candidates:
        for tld in TLDS:
            domain_list.append(f"{name}{tld}")

    tld_priority = {".com": 1, ".io": 2, ".xyz": 3}
    domain_list.sort(key=lambda x: (len(x), tld_priority[x[x.rfind('.'):]], x))

    return domain_list

def check_whois(domain):
    """
    Performs a raw socket WHOIS lookup.
    Returns True if available, False if taken.
    """
    tld = domain[domain.rfind('.'):]
    server = WHOIS_SERVERS.get(tld)

    if not server:
        print(f"No WHOIS server for {tld}")
        return False

    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        s.connect((server, 43))
        s.send(f"{domain}\r\n".encode())

        response = b""
        while True:
            data = s.recv(4096)
            if not data:
                break
            response += data
        s.close()

        response_text = response.decode(errors='ignore').lower()

        # Check patterns
        if "no match" in response_text: # .com
            return True
        if "not found" in response_text: # .io, .xyz usually
            return True
        if "is free" in response_text:
            return True

        return False

    except Exception as e:
        print(f"Error checking {domain}: {e}")
        return False

def main():
    print("Generating domain candidates...")
    candidates = generate_candidates()
    print(f"Generated {len(candidates)} candidates.")

    available_domains = []
    print("\nChecking availability (WHOIS)...")

    count = 0
    for domain in candidates:
        if len(available_domains) >= 10:
            break

        # Skip known high-value dictionary words to save time/requests
        # if domain in ["bird.com", "owl.com", "byrd.com", "bird.io", "owl.io"]:
        #    continue

        print(f"Checking {domain}...", end=" ", flush=True)
        is_free = check_whois(domain)

        if is_free:
            print("AVAILABLE")
            available_domains.append(domain)
        else:
            print("TAKEN")

        time.sleep(1) # Be nice to WHOIS servers

    print("\n--- Top 10 Potential Domains ---")
    for d in available_domains:
        print(d)

    with open("available_domains.txt", "w") as f:
        f.write("Available Domains (Verified via WHOIS):\n")
        f.write("Note: Price not verified. Check registrar.\n\n")
        for d in available_domains:
            f.write(f"{d}\n")

if __name__ == "__main__":
    main()
