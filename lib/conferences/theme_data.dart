import 'package:flutter/material.dart';
Color bgColor= Colors.white;
Color bgColor2= Colors.white;
Color fontColor= Colors.black;
Color fontGrey=Color.fromRGBO(48, 48, 48, 48);
Color fontColor2=Colors.grey;
Color indexHeaderBG=Colors.grey;
Color indexHeaderTitle=Colors.grey;
Color indexHeaderSubTitle=Colors.grey;
Color indexHeaderDate=Colors.grey;

String deviceTheme="";

updateTheme(){
  if(deviceTheme == "dark"){
    //darktheme
    bgColor= Color.fromRGBO(7, 23, 23, 1);
    bgColor2= Color.fromRGBO(22, 39, 39, 1);
    fontColor= Colors.white;
    fontColor2= Color.fromRGBO(240, 240, 240, 1);
    fontGrey= Color.fromRGBO(55, 69, 68, 1);
    indexHeaderBG=Color.fromRGBO(27, 44, 44, .9);
    indexHeaderTitle=Colors.white;
    indexHeaderSubTitle=Color.fromRGBO(235, 235, 235, 1);
    indexHeaderDate=Color.fromRGBO(245, 245, 245, 1);
  }
  else{
    //light theme
    bgColor= Color.fromRGBO(245, 245, 245, 1);
    bgColor2= Color.fromRGBO(235, 235, 235, 1);
    fontColor= Colors.black;
    fontColor2= Color.fromRGBO(50, 50, 50, 1);
    fontGrey= Color.fromRGBO(169, 170, 173, 1);
    indexHeaderBG=Color.fromRGBO(230, 230, 230, 1);
    indexHeaderTitle=Color.fromRGBO(100, 100, 100, 1);
    indexHeaderSubTitle=Color.fromRGBO(120, 120, 120, 1);
    indexHeaderDate=Color.fromRGBO(140, 140, 140, 1);
  }
}