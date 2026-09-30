const int BUTTON_PIN = 7;

const int BUZZER = 11;
const int TRIG_PIN = 10;
const int ECHO_PIN = 9;
const int SIGNAL = 6;
const int BLUE = 2;
const int YELLOW = 4;
const int GREEN = 3;

bool systemOn = false;      
int lastButtonState = HIGH;  

long puls(int inp){
  
  
  while(digitalRead(inp) == LOW){
  }

  unsigned long start = micros();
  while((micros() - start) < 1000000){
    if( digitalRead(inp) == LOW){
     
      return micros() - start;
    }
  }
  return -1;
}

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(BUZZER, OUTPUT);

  pinMode(SIGNAL, OUTPUT);

  pinMode(BLUE, OUTPUT);
  pinMode(YELLOW, OUTPUT);
  pinMode(GREEN, OUTPUT);
  Serial.begin(9600); 
}

void loop() {
  int currentState = digitalRead(BUTTON_PIN);
  if(lastButtonState == HIGH && currentState == LOW){
    systemOn = !systemOn;
    delay(50);
  }
  lastButtonState = currentState;
  if(systemOn == true){
    digitalWrite(TRIG_PIN,LOW);
    
    delay(2);
    digitalWrite(TRIG_PIN,HIGH);
    delay(10);
    digitalWrite(TRIG_PIN,LOW);
 
    long time = puls(ECHO_PIN);
    // long time1 = pulseIn(ECHO_PIN,HIGH);
    int distance =time * 0.0343 /2;
    // int distance1 =time1 * 0.0343 /2;
    
    digitalWrite(SIGNAL,HIGH);
    digitalWrite(BLUE,LOW);
    digitalWrite(GREEN,LOW);
    digitalWrite(YELLOW,LOW);

    Serial.print("time ");
    Serial.println(distance,DEC);
    Serial.print("distance is ");
    Serial.print(distance,DEC);
    Serial.println("cm");
     
    // Serial.println(millis(),DEC);
    if(distance < 10 && distance >= 0){
      digitalWrite(BLUE,HIGH);
      
      // digitalWrite(BUZZER,HIGH);
      
    }else if( distance < 30){
      digitalWrite(YELLOW,HIGH);
      // digitalWrite(BUZZER, HIGH); 
      // delay(150);               
      // digitalWrite(BUZZER, LOW);  
      // delay(150);  
    }else if (distance < 400){
      digitalWrite(GREEN,HIGH);
      // digitalWrite(BUZZER, HIGH); 
      // delay(350);               
      // digitalWrite(BUZZER, LOW);  
      // delay(350);  
    }
   if(distance < 5){
      digitalWrite(BUZZER, HIGH); 
      delay(10);               
      digitalWrite(BUZZER, LOW);  
      delay(10);
  }
   else if(distance < 10){
      digitalWrite(BUZZER, HIGH); 
      delay(25);               
      digitalWrite(BUZZER, LOW);  
      delay(25);
  }
  
  // else if(distance < 20){
  //     digitalWrite(BUZZER, HIGH); 
  //     delay(75);               
  //     digitalWrite(BUZZER, LOW);  
  //     delay(75);
  // }
  
  
  // else if(distance < 40){
  //     digitalWrite(BUZZER, HIGH); 
  //     delay(100);               
  //     digitalWrite(BUZZER, LOW);  
  //     delay(100);
  // }
  
  else if(distance < 13){
      digitalWrite(BUZZER, HIGH); 
      delay(60);               
      digitalWrite(BUZZER, LOW);  
      delay(60);
  }
  // else if(distance < 80){
  //     digitalWrite(BUZZER, HIGH); 
  //     delay(140);               
  //     digitalWrite(BUZZER, LOW);  
  //     delay(140);
  // }
  
  else if(distance < 15){
      digitalWrite(BUZZER, HIGH); 
      delay(80);               
      digitalWrite(BUZZER, LOW);  
      delay(80);
  }
  else if(distance < 17){
      digitalWrite(BUZZER, HIGH); 
      delay(120);               
      digitalWrite(BUZZER, LOW);  
      delay(120);
  }
  else if(distance < 20){
      digitalWrite(BUZZER, HIGH); 
      delay(150);               
      digitalWrite(BUZZER, LOW);  
      delay(150);
  }else{
      digitalWrite(BUZZER, HIGH); 
      delay(250);               
      digitalWrite(BUZZER, LOW);  
      delay(250);

  }
  }else{
    digitalWrite(SIGNAL,LOW);
    digitalWrite(BLUE,LOW);
    digitalWrite(GREEN,LOW);
    digitalWrite(YELLOW,LOW);
  }
  
  // delay(500);
}
