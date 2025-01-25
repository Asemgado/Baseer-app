import google.generativeai as genai
import psycopg2, base64, io, csv, httpx
from PIL import Image


conn_str = "data_base_connection_string"
genai.configure(api_key="api_key")
model = genai.GenerativeModel(model_name='models/Baseer')


pre_data = []
with open('data.csv', 'r', encoding='utf-8') as file:
    csv_reader = csv.DictReader(file)
    for row in csv_reader:
        pre_data.append({"role": "user", "parts": row['user']})
        pre_data.append({"role": "model", "parts": row['model']})




def Message2DB(user_id, input_text, output_text):
    conn = psycopg2.connect(conn_str)
    if conn is None:
        raise Exception("Failed to connect to the database when adding to History")
    cur = conn.cursor()
    cur.execute(f"insert into history (user_id, message, response) values ({user_id}, '{input_text}', '{output_text}')")
    conn.commit()
    conn.close()



def generate_response(user_id, prompt):
    data = pre_data.copy()
    data.append({"role": "user", "parts": prompt})
    response = model.generate_content(data).text.strip()
    Message2DB(user_id, prompt, response)
    return response


def image_recognition(user_id, photo, prompt):
    image = Image.open(io.BytesIO(base64.b64decode(photo)))
    response = model.generate_content([prompt, image]).text.strip()
    Message2DB(user_id, prompt, response)
    return response



def register(username, fullname, password, phone, address, illness, gender, age, imergency_contact):
    conn = psycopg2.connect(conn_str)
    if conn is None:
        raise Exception("Failed to connect to the database when adding user")
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE username = %s OR phone = %s", (username, phone))
    if cur.fetchone():
        raise Exception("Username already exists")
    
    cur.execute(f"insert into users (username, fullname, password, phone, address, illness, gender, age, imergency_contact) values ('{username}', '{fullname}', '{password}', '{phone}', '{address}', '{illness}', '{gender}', '{age}', '{imergency_contact}')")
    conn.commit()
    conn.close()




def login(username, password):
    conn = psycopg2.connect(conn_str)
    if conn is None:
        raise Exception("Failed to connect to the database when logging in")
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE username = %s AND password = %s", (username, password))
    user = cur.fetchone()
    conn.close()
    if user:
        return user[0]
    else:
        raise Exception("خطأ في اسم المستخدم أو كلمة المرور")





def get_user_info(user_id):
    conn = psycopg2.connect(conn_str)
    if conn is None:
        raise Exception("Failed to connect to the database when getting user info")
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE id = %s", (int(user_id),))
    user = cur.fetchone()
    conn.close()
    if user:
        return user
    else:
        raise Exception("المستخدم غير موجود")
    


def get_phone(response):
    conn = psycopg2.connect(conn_str)
    if conn is None:
        raise Exception("Failed to connect to the database when getting phone")
    cur = conn.cursor()
    cur.execute("SELECT name , phone FROM contacts")
    contacts = cur.fetchall()
    conn.close()
    for name, phone in contacts:
        if name in response:
            response = response.replace(name, "")
            return phone, response
    return None, response
    


def get_order(response):
    oreders = ["CAMERA", "LOCATION", "PHONE", "EMERGENCY", "BLUETOOTH", "SOUND", "WIFI", "TIME","WHATSAPP"]
    for order in oreders:
        if order in response:
            response = response.replace(order, "")
            return order, response
    return None, response




async def whatsapp(name, number, message):
    
    url = "https://graph.facebook.com/{{VERSION}}/{{PHONE_ID}}/messages"
    headers = {
        "Authorization": "Bearer {{ACCESS_TOKEN}}",
        "Content-Type": "application/json"
    }
    payload = {
        "messaging_product": "whatsapp",
        "to": "2" + number,
        "type": "template",
        "template": {
            "name": "baseer",
            "language": {
                "code": "ar_EG"
            },
            "components": [
                {
                    "type": "body",
                    "parameters": [
                        {
                            "type": "text",
                            "parameter_name": "name",
                            "text": name
                        },
                        {
                            "type": "text",
                            "parameter_name": "subject",
                            "text": message
                        }
                    ]
                }
            ]
        }
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(url, headers=headers, json=payload)
        return response.json()
