import sys

def get_location(filename, pos):
    with open(filename, 'r') as f:
        content = f.read()
    
    line = 1
    col = 1
    for i in range(pos):
        if content[i] == '\n':
            line += 1
            col = 1
        else:
            col += 1
            
    snippet = content[max(0, pos-20):min(len(content), pos+20)]
    print(f"Position {pos} is at line {line}, column {col}")
    print(f"Snippet: |{snippet}|")

if __name__ == "__main__":
    get_location(sys.argv[1], int(sys.argv[2]))
