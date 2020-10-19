import 'package:flutter/material.dart';
Color bgColor= Colors.white;
Color appBarColor=Colors.blue;
Color fontColor=Colors.white;
Color fontGrey=Colors.white;
Color appBarFColor=Colors.white;
Color appBarFColorActive=Colors.blue;
Color fabBGColor=Colors.blue;

String deviceTheme="";

updateTheme(){
  if(deviceTheme == "dark"){
    //darktheme
    bgColor= Color.fromRGBO(16, 29, 36, 1);
    appBarColor= Color.fromRGBO(34, 45, 54, 1);
    fontColor=Colors.white;
    fontGrey=Color.fromRGBO(200, 200, 200, 1);
    appBarFColor=Color.fromRGBO(145, 145, 145, 1);
    appBarFColorActive=Colors.blue;
    fabBGColor= Color.fromRGBO(34, 45, 54, 1);
  }
  else{
    //light theme
    bgColor= Colors.white;
    appBarColor= Color.fromRGBO(66, 99, 130, 1);
    fontColor=Color.fromRGBO(20, 20, 20, 1);
    fontGrey=Color.fromRGBO(80, 80, 80, 1);
    appBarFColor=Color.fromRGBO(208, 230, 246, 1);
    appBarFColorActive=Colors.white;
    fabBGColor= Color.fromRGBO(66, 99, 130, 1);
  }
}