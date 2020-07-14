import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

import './dbs.dart';
import './globals.dart' as globals;
import './launch_page.dart';
class ConfirmEmail extends StatefulWidget{
  _ConfirmEmail createState(){
    return _ConfirmEmail();
  }
  final String emailStr; final String fullnameStr;
  ConfirmEmail(this.emailStr, this.fullnameStr);
}

class _ConfirmEmail extends State<ConfirmEmail>{
  double toastOpacity=0;
  String toastText="";

  DBTables dbTables=DBTables();

  final formKey= GlobalKey<FormState>();
  TextEditingController _activateCodeCtr= TextEditingController();
  TextEditingController _newPasswordCtr=TextEditingController();
  FocusNode _newpassnode= FocusNode();

  tryConfirm()async{
    if(formKey.currentState.validate()){
      showLoader(message: "A moment please ...");
      try{
        Database con= await dbTables.loginCon();
        var result= await con.rawQuery("select * from user_login limit 1");
        if(result.length == 1){
          String uemail= result[0]["email"];
          String password= result[0]["password"];
          String status= result[0]["status"];
          if(status == "PENDING"){
            String url=globals.globBaseUrl + "?process_as=activate_account";
            http.Response resp= await http.post(
              url,
              body: {
                "email": uemail,
                "password": password,
                "newpassword": _newPasswordCtr.text,
                "code": _activateCodeCtr.text
              }
            );
            if(resp.statusCode == 200){
              hideLoader();
              var respObj= jsonDecode(resp.body);
              if(respObj["status"] == "success"){
                formKey.currentState.reset();
                await con.execute("update user_login set password=?, status=?", [_newPasswordCtr.text, 'ACTIVATED']);
                showToast(
                  text: respObj["message"],
                  persistDur: Duration(seconds: 7)
                );
                _newPasswordCtr.text="";
                _activateCodeCtr.text="";
                Future.delayed(
                  Duration(seconds: 7),
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
                  persistDur: Duration(seconds: 12)
                );
              }
            }
            else{
              hideLoader();
              showToast(
                text: "Sorry, we can not handle this request at this time, try again later",
                persistDur: Duration(seconds: 12)
              );
            }
          }
        }
      }
      catch(ex){
        showToast(
          text: "Kindly ensure that your device is properly connected to the internet",
          persistDur: Duration(seconds: 12)
        );
      }
    }
  }

  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    return WillPopScope(
      child: Scaffold(
        body: Container(
          child: Stack(
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(left: 24, right: 24, top: 120),
                decoration: BoxDecoration(
                  color: Colors.white,
                  image: DecorationImage(
                    image: AssetImage(
                      "./images/plain_logo.png",
                    ),
                    fit: BoxFit.cover
                  )
                ),
                child: Container(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      children: <Widget>[
                        Container(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Hey " + widget.fullnameStr,
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontFamily: "ubuntu"
                            ),
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(bottom: 36),
                          child: Text(
                            "Good to have you here",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white
                            ),
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(bottom: 16),
                          child: Text(
                            "Kindly find an activation code, sent to " + widget.emailStr,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(top:12, bottom: 12, left:16, right: 16),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(43, 20, 126, 1),
                          ),
                          child: TextFormField(
                            controller: _activateCodeCtr,
                            style: TextStyle(
                              color: Colors.white
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter activation code here",
                              labelText: "Activation Code",
                              labelStyle: TextStyle(
                                color: Colors.white
                              ),
                              hintStyle: TextStyle(
                                color: Colors.white
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white
                                )
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white
                                )
                              )
                            ),
                            validator: (value){
                              if(value.isEmpty){
                                return "Provide activation code here";
                              }
                              return null;
                            },
                            onEditingComplete: (){
                              FocusScope.of(_pageContext).requestFocus(_newpassnode);
                            },
                            textInputAction: TextInputAction.next,
                          ),
                        ), //activation code input box

                        Container(
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.only(top:12, bottom: 12, left:16, right: 16),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(43, 20, 126, 1),
                          ),
                          child: TextFormField(
                            controller: _newPasswordCtr,
                            style: TextStyle(
                              color: Colors.white
                            ),
                            focusNode: _newpassnode,
                            decoration: InputDecoration(
                              hintText: "Provide a new password for this account",
                              labelText: "New Password",
                              labelStyle: TextStyle(
                                color: Colors.white
                              ),
                              hintStyle: TextStyle(
                                color: Colors.white
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white
                                )
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white
                                )
                              )
                            ),
                            validator: (value){
                              if(value.length<7){
                                return "Kindly provide a password with at least seven characters";
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.go,
                            onEditingComplete: (){
                              tryConfirm();
                            },
                          ),
                        ), //new password box

                        Container(
                          child: RaisedButton(
                            color: Color.fromRGBO(41, 99, 41, 1),
                            textColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.only(top:16, bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)
                            ),
                            onPressed: (){
                              tryConfirm();
                            },
                            child: Text(
                              "ACTIVATE"
                            ),
                          ),
                        )
                      ],
                    ), 
                  ),
                )
              ), //form body

              Positioned(
                bottom: 150,
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
              ),
            ],
          ),
        ),
      ), 
      onWillPop: ()async{
        SystemChannels.platform.invokeMethod("SystemNavigator.pop");
        return true;
      }
    );
  }//page build method

  BuildContext dlgCtx;
  displayAlert({@required Widget title, @required Widget content,  List<Widget> action})async{
    await showDialog(
      context: _pageContext,
      builder: (BuildContext localCtx){
        dlgCtx=localCtx;
        return AlertDialog(
          title: title,
          content: content,
          actions: (action!=null && action.length>0) ? action: null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)
          ),
        );
      }
    );
  }//displayAlert

  
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
}