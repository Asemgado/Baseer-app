import uvicorn, transformer, httpx
from fastapi.responses import RedirectResponse
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi.concurrency import run_in_threadpool



# Initialize FastAPI
app = FastAPI()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Login(BaseModel):
    username: str
    password: str


class Request(BaseModel):
    user_id: str
    message: str

class ImageRequest(BaseModel):
    user_id: str
    image: str
    message: str

class register(BaseModel):
    username: str
    fullname: str
    password: str
    phone: str
    address: str
    illness: str
    gender: str
    age: str
    imergency_contact: str

class whatsapp(BaseModel):
    user_id: str
    number: str
    message: str

class emergency(BaseModel):
    user_id: str
    message: str


@app.get('/')
def welcome():
    return RedirectResponse(url='/docs')



@app.post('/chat')
async def chat(request: Request):
    try:
        prompt = request.message
        user_id = request.user_id
    
        if not prompt:
            raise HTTPException(status_code=400, detail="لم يتم ارسال الرسالة")
        
        back_response = await run_in_threadpool(transformer.generate_response, user_id, prompt)
        order, response = await run_in_threadpool(transformer.get_order, back_response)
        response = response.replace('\n', ' ').replace('-', ' ').strip()

        if order:
            if order == "PHONE":
                phone, response = await run_in_threadpool(transformer.get_phone, response)
                return {
                    'order': order,
                    'message': response,
                    'phone': phone,
                    'response': back_response
                }
            elif order == "WHATSAPP":
                name = await run_in_threadpool(transformer.get_user_info, user_id)
                phone, response = await run_in_threadpool(transformer.get_phone, response)
                request = await transformer.whatsapp(name[2], phone, response)
                return {
                    'order': order,
                    'message': "تم ارسال الرسالة",
                    'response': request
                }
            else :
                return {
                    'message': response,
                    'order': order,
                    'response': back_response
                }
        else :
            return {
                'message': back_response
            }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))




@app.post('/image')
async def image(request: ImageRequest):
    try:
        image = request.image 
        prompt = request.message
        user_id = request.user_id
        
        if not image:
            raise HTTPException(status_code=400, detail="لم يتم ارسال الصورة")
        
        response = await run_in_threadpool(transformer.image_recognition, user_id, image, prompt)
        return {
            'message': response
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))




@app.post("/emergency")
async def emergency(request: emergency):
    user_id = request.user_id
    message = request.message
    name = await run_in_threadpool(transformer.get_user_info, user_id)
    request = await transformer.whatsapp(name[2], name[9], message)
    return {
        'message': "تم ارسال الي الطوارئ",
        'response': request
    }


@app.post('/login')
async def login(request: Login):
    username = request.username
    password = request.password
    if not username or not password:
        raise HTTPException(status_code=400, detail="لم يتم ارسال اسم المستخدم أو كلمة المرور")
    try:
        user_id = await run_in_threadpool(transformer.login, username, password)
        if id:
            return {
                "message": "تم تسجيل الدخول بنجاح",
                "id": user_id
            }
        else:
            raise HTTPException(status_code=401, detail="خطأ في اسم المستخدم أو كلمة المرور")

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))





@app.post('/registeration')
async def register(request: register):
    try:
        username = request.username
        fullname = request.fullname
        password = request.password
        phone = request.phone
        address = request.address
        illness = request.illness
        gender = request.gender
        age = request.age
        imergency_contact = request.imergency_contact
        if not username or not fullname or not password or not phone or not address or not illness or not gender or not age or not imergency_contact:
            raise HTTPException(status_code=400, detail="لم يتم ارسال جميع البيانات")
        await run_in_threadpool(transformer.register, username, fullname, password, phone, address, illness, gender, age, imergency_contact)
        return {
            "message": "تم تسجيل الحساب بنجاح"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))    





@app.get('/profile/{user_id}')
async def get_user(user_id: str):
    try:
        data = await run_in_threadpool(transformer.get_user_info, user_id)
        return {
            "message": "تم جلب الملف الشخصي بنجاح",
            "data": data
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



if __name__ == '__main__':
    uvicorn.run("app:app", host="127.0.0.1", port=8000, workers=4, reload=True)
