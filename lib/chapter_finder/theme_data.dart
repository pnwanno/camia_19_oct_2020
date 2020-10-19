import 'package:flutter/material.dart';
Color bgColor= Colors.white;
Color bgColorVar1= Color.fromRGBO(245, 245, 245, 1);
Color fontColor= Colors.black;
Color fontGrey=Color.fromRGBO(48, 48, 48, 48);
Color fontColor2=Colors.grey;
Color activeIcon=Colors.blue;
Color homeDescText=Colors.blue;
Color borderColor=Colors.grey;
Color blurColor=Colors.grey;

String deviceTheme="";

updateTheme(){
  if(deviceTheme == "dark"){
    //darktheme
    bgColor= Color.fromRGBO(48, 49, 52, 1);
    bgColorVar1= Color.fromRGBO(41, 46, 51, 1);
    fontColor= Colors.white;
    fontColor2= Color.fromRGBO(224, 225, 226, 1);
    fontGrey= Color.fromRGBO(139, 142, 146, 1);
    activeIcon=Colors.blue;
    homeDescText=Colors.blueAccent;
    borderColor=Color.fromRGBO(100, 100, 100, 1);
    blurColor=Color.fromRGBO(35, 35, 35, 1);
  }
  else{
    //light theme
    bgColor= Colors.white;
    bgColorVar1= Color.fromRGBO(241, 243, 244, 1);
    fontColor= Colors.black;
    fontColor2= Color.fromRGBO(70, 70, 70, 1);
    fontGrey= Color.fromRGBO(159, 159, 159, 1);
    activeIcon=Colors.blue;
    homeDescText=Colors.lightBlue;
    borderColor=Color.fromRGBO(200, 200, 200, 1);
    blurColor=Color.fromRGBO(180, 180, 180, 1);
  }
}