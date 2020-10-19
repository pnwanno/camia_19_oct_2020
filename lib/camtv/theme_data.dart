import 'package:flutter/material.dart';
Color bgColor= Colors.white;
Color bgColorVar1= Color.fromRGBO(245, 245, 245, 1);
Color fontColor= Colors.black;
Color usernameColor= Colors.deepOrange;
Color drawerHeadBG=Color.fromRGBO(245, 245, 245, 1);
Color drawerLine= Colors.grey; //color for the lines that separates the drawer items
Color drawerItemColor= Colors.white;//color for the items listed in the drawer
Color drawerItemFontColor= Colors.black;
Color toastBGColor=Color.fromRGBO(32, 32, 32, 1);
Color toastFontColor=Colors.white;
Color tvProfileLabel= Colors.grey;
Color profileIcons=Color.fromRGBO(48, 48, 48, 48);
Color fontGrey=Color.fromRGBO(48, 48, 48, 48);

String deviceTheme="";

updateTheme(){
  if(deviceTheme == "dark"){
    //darktheme
    bgColor= Color.fromRGBO(32, 32, 32, 1);
    bgColorVar1= Color.fromRGBO(28, 28, 28, 1);
    fontColor= Colors.white;
    usernameColor= Colors.grey;
    drawerHeadBG=Color.fromRGBO(28, 28, 28, 1);
    drawerLine= Color.fromRGBO(42, 42, 42, 1);
    drawerItemColor=Colors.transparent;
    drawerItemFontColor=Colors.white;
    toastBGColor= Color.fromRGBO(120, 120, 120, 1);
    toastFontColor=Colors.white;
    tvProfileLabel= Colors.grey;
    profileIcons=Colors.white;
    fontGrey= Color.fromRGBO(120, 120, 120, 1);
  }
  else{
    //light theme
    bgColor= Colors.white;
    bgColorVar1= Color.fromRGBO(245, 245, 245, 1);
    fontColor= Colors.black;
    usernameColor= Colors.deepOrange;
    drawerHeadBG=Color.fromRGBO(245, 245, 245, 1);
    drawerLine= Color.fromRGBO(220, 220, 220, 1);
    drawerItemColor=Colors.transparent;
    drawerItemFontColor=Colors.black;
    toastBGColor= Color.fromRGBO(32, 32, 32, 1);
    toastFontColor=Colors.white;
    tvProfileLabel= Colors.grey;
    profileIcons=Color.fromRGBO(48, 48, 48, 48);
    fontGrey= Colors.grey;
  }
}