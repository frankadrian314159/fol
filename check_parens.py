import sys

def check_parens(filename):
    with open(filename, 'r') as f:
        content = f.read()
    
    count = 0
    for i, char in enumerate(content):
        if char == '(':
            count += 1
        elif char == ')':
            count -= 1
        
        if count < 0:
            print(f"Excess closing paren at position {i}")
            return False
            
    if count > 0:
        print(f"Missing {count} closing parens")
        return False
    elif count < 0:
        print(f"Excess {abs(count)} closing parens")
        return False
    else:
        print("Parens are balanced")
        return True

if __name__ == "__main__":
    check_parens(sys.argv[1])
