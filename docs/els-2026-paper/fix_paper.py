import re

path = r'c:\Users\frank\Projects\FOL\fol\docs\els-2026-paper\els-2026-paper.tex'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the long broken line
pattern = r'Versioning overhead.*Skip skipped.*'
replacement = r'Versioning overhead---the cost of recovering the current state of an object via chain-replay is $O(H)$ where $H$ is the number of redefinitions. Since redefinitions are infrequent, $H$ is typically small ($< 10$). Replay cost is bounded by a few microseconds per instance, paid only once during lazy migration. Once migrated, the object\'s slots reside in the current schema\'s preferred layout (native or trie), and subsequent reads proceed at the standard $1.4-2.1\times$ read rate.'

new_content = re.sub(pattern, replacement, content)

# Also fix the Arabic and typo if they are still there
new_content = new_content.replace('While libraries مثل FSet', 'While libraries such as FSet')
new_content = new_content.replace('FOL demonstrate that', 'FOL demonstrates that')

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)
