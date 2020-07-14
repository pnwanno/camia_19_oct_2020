import 'dart:convert';

import 'package:camia/signup.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import './globals.dart' as globals;
import './dbs.dart';
import './confirm_email.dart';
import 'launch_page.dart';

class Signin extends StatefulWidget{
  _Signin createState(){
    return _Signin();
  }
}

class _Signin extends State<Signin>{
  final formKey= GlobalKey<FormState>();
  TextEditingController usernameCtr= TextEditingController();
  TextEditingController passnameCtr= TextEditingController();
  FocusNode passnameNode= FocusNode();

  DBTables dbTables= new DBTables();
  double toastOpacity=0;
  String toastText="";
  Size _screenSize;
  Widget pageBody(){
  return Stack(
    children: <Widget>[
      Positioned(
        left: (_screenSize.height < 641) ? -100  : (_screenSize.height < 902) ? -130: -150, 
        top: (_screenSize.height < 641) ? -150 : (_screenSize.height < 902) ? -100 : -100,
        child: Container(
              width:  (_screenSize.height < 641) ? 500 : (_screenSize.height < 902) ? 550 : 900,
              height: (_screenSize.height < 641) ? 450 : (_screenSize.height < 902) ? 500 : 850,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("./images/plain_logo.png"),
                  fit: BoxFit.cover,
                  alignment: Alignment.center
                )
              ),
            ) 
      ),//camia logo
      Positioned(
        left: 40, 
        top: (_screenSize.height < 641) ? 80 : (_screenSize.height < 902) ? 150 : 320,
        child: Container(
          child: Column(
            children: <Widget>[
              Container(
                child: Text(
                  "WELCOME",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: "ubuntu",
                    fontSize: (_screenSize.height < 641) ? 40 : 55
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(top:12),
                child: Text(
                  "Login!",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 32,
                    fontFamily: "courgette"
                  ),
                ),
              )
            ],
          ),
        ) 
      ),
      Container(
        width: MediaQuery.of(_pageContext).size.width,
        height: MediaQuery.of(_pageContext).size.height,
         child: ListView(
          children: <Widget>[
            Container(
              margin: (_screenSize.height < 641) ? EdgeInsets.only(top: 250) : (_screenSize.height < 902) ? EdgeInsets.only(top: 400) : EdgeInsets.only(top: 750),
                padding: EdgeInsets.only(left: 20, right: 20),
                child: Form(
                  key: formKey,
                  child: Container(
                  height: (_screenSize.height < 641) ? _screenSize.height - 250 : (_screenSize.height < 902) ? _screenSize.height - 400 : _screenSize.height - 750,
                  child: ListView(
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(bottom:16),
                        child: TextFormField(
                          controller: usernameCtr,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: "Username",
                            hintText: "Email or Phone number",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onEditingComplete: (){
                            FocusScope.of(_pageContext).requestFocus(passnameNode);
                          },
                          validator: (value){
                            if(value.isEmpty){
                              return "Username is required";
                            }
                            return null;
                          },
                        ),
                      ), //username

                      Container(
                        margin: EdgeInsets.only(bottom:16),
                        child: TextFormField(
                          obscureText: true,
                          controller: passnameCtr,
                          focusNode: passnameNode,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            labelText: "Password",
                            hintText: "Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onEditingComplete: (){
                              tryLogin();
                          },
                          validator: (value){
                            if(value.isEmpty){
                              return "Password is required";
                            }
                            return null;
                          },
                        ),
                      ),//password

                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        child: RaisedButton(
                          padding: EdgeInsets.only(top: 12, bottom: 12),
                          color: Color.fromARGB(73, 74, 174, 1),
                          textColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)
                          ),
                          onPressed: (){
                            tryLogin();
                          },
                          child: Text(
                            "Login"
                          ),
                        ),
                      ),//login button

                      Container(
                        margin: EdgeInsets.only(bottom: 12),
                        child: RichText(
                          textScaleFactor: (_screenSize.height > 901) ? 1.5 : 1,
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: "Don't have an account?",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16
                                )
                              ),
                              TextSpan(
                                text: " Tap here to signup",
                                style: TextStyle(
                                  color: Color.fromRGBO(27, 126, 187, 1),
                                  fontSize: 15
                                ),
                                recognizer: TapGestureRecognizer()..onTap = (){
                                  return Navigator.of(_pageContext).push(
                                    MaterialPageRoute(
                                      builder: (BuildContext ctx){
                                        return Signup();
                                      }
                                    )
                                  );
                                }
                              )
                            ]
                          )
                        ),
                      ),//don't have an account

                      Container(
                        child: RichText(
                          textScaleFactor: (_screenSize.height > 901) ? 1.5 : 1,
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: "Tap here",
                                style: TextStyle(
                                  color: Color.fromRGBO(27, 126, 187, 1),
                                  fontSize: 15
                                ),
                                recognizer: TapGestureRecognizer()..onTap= () async{
                                  Database con= await dbTables.loginCon();
                                  var result=await con.rawQuery("select * from user_login");
                                  if(result.length == 0){
                                    showToast(
                                      persistDur: Duration(milliseconds: 7000),
                                      text: "Register an account first, to continue"
                                    );
                                  }
                                  else{
                                    String curStatus= result[0]["status"];
                                    if(curStatus == "PENDING"){
                                      String curEmail=result[0]["email"];
                                      Navigator.of(_pageContext).push(
                                        MaterialPageRoute(
                                          builder: (BuildContext ctx){
                                            return ConfirmEmail(curEmail, result[0]["fullname"]);
                                          }
                                        )
                                      );
                                    }
                                    else{
                                      showToast(
                                        persistDur: Duration(seconds: 2),
                                        text: "Email already verified, kindly login"
                                      );
                                    }
                                  }
                                }
                              ),
                              TextSpan(
                                text: " to confirm your email address",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16
                                )
                              )
                            ]
                          )
                        )
                      )
                    ],
                  ) ,
                )
              ),
              
            ),
            
          ],
        ),
      ),// the form

      Positioned(
        bottom: 120,
        width: MediaQuery.of(_pageContext).size.width - 60,
        left: 30,
        child: AnimatedOpacity(
          opacity: toastOpacity, 
          duration: Duration(milliseconds: 500),
          child: Container(
            padding: EdgeInsets.only(top: 12, bottom: 12, left: 16, right: 16),
            decoration: BoxDecoration(
              color: Color.fromRGBO(40, 40, 40, .8),
              borderRadius: BorderRadius.circular(24)
            ),
            alignment: Alignment.center,
            child: Text(
              toastText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16
              ),
            ),
          ),
        )
      ), //mimic android toast
      
    ],
  );
}//page body

  tryLogin()async{
    if(formKey.currentState.validate()){
      String url=globals.globBaseUrl + "?process_as=try_login";
      showLoader(message: "A moment please ...");
      try{
        http.Response resp= await http.post(
          url,
          body: {
            "username": usernameCtr.text,
            "password": passnameCtr.text
          }
        );
        if(resp.statusCode == 200){
          var respObj= jsonDecode(resp.body);
          hideLoader();
          if(respObj["status"] == "success"){
            Database con= await dbTables.loginCon();
            await con.execute("delete from user_login");
            String ustatus="ACTIVATED";
            await con.execute("insert into user_login (email, password, fullname, dp, phone, status, user_id) values (?, ?, ?, ?, ?, ?, ?)", [respObj["email"], respObj["password"], respObj["fullname"], respObj["dp"], respObj["phone"], ustatus, respObj["user_id"]]);
            showToast(
              text: respObj["message"],
              persistDur: Duration(seconds: 3)
            );
            Future.delayed(
              Duration(seconds: 4),
              (){
                Navigator.of(_pageContext).push(
                  MaterialPageRoute(
                    builder: (BuildContext ctx){
                      return LaunchPage();
                    }
                  )
                );
              }
            );
          }
          else{
            showToast(
              text: respObj["message"],
              persistDur: Duration(seconds: 15)
            );
          }
        }
        else{
          hideLoader();
          showToast(
            text: "Sorry, we could not complete this request at this time. Try again",
            persistDur: Duration(seconds: 7)
          );
        }
      } 
      catch(ex){
        hideLoader();
        showToast(
          text: "Kindly ensure that your device is properly connected to the internet",
          persistDur: Duration(seconds: 3)
        );
      }
    }
  }

  hideLoader(){
    Navigator.pop(dlgCtx2);
  }

  BuildContext dlgCtx2;
  showLoader({String message}){
    showGeneralDialog(
      context: _pageContext,
      transitionDuration: Duration(milliseconds: 200), 
      pageBuilder: (BuildContext ctx, ani1, an2){
        dlgCtx2= ctx;
        return Material(
          color: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                message != null ? Container(
                  margin: EdgeInsets.only(bottom: 7),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Color.fromRGBO(34,139,34, 1)
                    ),
                  ),
                ): Container(),
                Container(
                  alignment: Alignment.center,
                  child:  CircularProgressIndicator(),
                )
              ],
            )
          ),
        );
      },
      barrierLabel: MaterialLocalizations.of(_pageContext).modalBarrierDismissLabel,
      barrierColor: Color.fromRGBO(100, 100, 100, .4),
      barrierDismissible: false
    );
  }

  showToast({String text, Duration persistDur}){
    setState(() {
      toastText=text;
      toastOpacity=1;
    });
    Future.delayed(
      persistDur,
      (){
        setState(() {
          toastOpacity=0;
        });
      }
    );
  }

  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(context).size;
    return WillPopScope(
        child: MaterialApp(
        home: Scaffold(
          body: pageBody()
        ),
      ), 
      onWillPop: (){
        return handlePagePop();
      }
    );
  }//page build

  handlePagePop() async{
    SystemChannels.platform.invokeMethod("SystemNavigator.pop");
    return true;
  }
}