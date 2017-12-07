import pyjokes

def joke(params):
    return {"joke": pyjokes.get_joke()}

