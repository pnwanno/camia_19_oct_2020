import 'dart:convert';

import 'package:drawing_animation/drawing_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sim_country_code/flutter_sim_country_code.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import './globals.dart' as globals;
import './dbs.dart';
import './confirm_email.dart';

class Signup extends StatefulWidget{
  _Signup createState(){
    return _Signup();
  }
}

class _Signup extends State<Signup>{
  
  String _uCountry="";
  TextEditingController _firstnameCtr=new TextEditingController();
  FocusNode _lastnameNode= FocusNode();
  TextEditingController _lastnameCtr=new TextEditingController();
  FocusNode _emailNode= FocusNode();
  TextEditingController _emailCtr=new TextEditingController();
  FocusNode _phoneNode= new FocusNode();
  TextEditingController _phoneCtr=new TextEditingController();
  FocusNode _genderNode= new FocusNode();
  FocusNode _dobNode= new FocusNode();
  FocusNode _submitNode= new FocusNode();
  DateTime _selDOB =DateTime.now();
  TextEditingController _dobCtr=TextEditingController();

  RegExp emExp= new RegExp(r"^[a-z_0-9.-]+\@[a-z_0-9-]+\.[a-z_0-9-]+(\.[a-z_0-9-]+)*$", multiLine: true);
  
  List<DropdownMenuItem<dynamic>> genderItem= List<DropdownMenuItem<dynamic>>();
  List<String> genderStr=["Male", "Female"];
  String selectedGender="";

  DBTables dbTables= DBTables();
  DateTime tdy= DateTime.now();
  double toastOpacity=0;
  String toastText= "";
  @override
  void initState() {
    trygetUserCountry();
    int genderCount= genderStr.length;
    for(int k=0; k<genderCount; k++){
      genderItem.add(
        DropdownMenuItem(
          child: Text(
            genderStr[k]
          ),
          value: genderStr[k],
        )
      );
    }

    
    super.initState();
  }
  trygetUserCountry()async{
    _uCountry= await FlutterSimCountryCode.simCountryCode;
  }

  final formKey= GlobalKey<FormState>();
  
  trySignup() async{
    if(formKey.currentState.validate()){
      try{
        String url= globals.globBaseUrl + "?process_as=try_register";
        showLoader(message: "A moment please ...");
        http.Response resp=await http.post(
          url,
          body: {
            "country": _uCountry,
            "firstname": _firstnameCtr.text,
            "lastname": _lastnameCtr.text,
            "email": _emailCtr.text,
            "phone": _phoneCtr.text,
            "gender": selectedGender,
            "dob": _dobCtr.text,
          }
        );
        if(resp.statusCode == 200){
          hideLoader();
          var respObj= jsonDecode(resp.body);
          if(respObj["status"]=="success"){
            Database con= await dbTables.loginCon();
            String retEm=respObj["email"];
            String retName=respObj["fullname"];
            String retDp=respObj["dp"];
            String retPhone=respObj["phone"];
            String pwd=respObj["password"];
            String serverUid= respObj["user_id"];
            String tmpStatus="PENDING";
            formKey.currentState.reset();
            _firstnameCtr.text="";
            _lastnameCtr.text="";
            _phoneCtr.text="";
            _emailCtr.text="";
            selectedGender="Male";

            con.execute("delete from user_login");
            con.execute("insert into user_login (email, password, fullname, dp, phone, status, user_id) values (?, ?, ?, ?, ?, ?, ?)", [retEm, pwd, retName, retDp, retPhone, tmpStatus, serverUid]);
            successAlert(retEm, retName);
          }
          else{
            displayAlert(
              title: Center(child: Text("Error"),),
              content: Container(
                height: 150,
                child: Column(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(bottom: 12),
                      height: 70,
                      child: AnimatedDrawing.svg(
                        "./images/exclamation.svg",
                        run: true,
                        duration: Duration(milliseconds: 1000),
                        animationCurve: Curves.bounceOut,
                      ),
                    ),
                    Container(
                      child: Text(
                        respObj["message"]
                      ),
                    )
                  ],
                )
              )
            );//error message
          }
        }
      }
      catch(ex){
        Future.delayed(
          Duration(milliseconds: 1000),
          (){
            showToast(
              text: "Kindly ensure that your device is properly connected to the internet",
              persistDur: Duration(seconds: 12)
            );
          }
        );
      }
    }
  }

  Widget pageBody(){
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Container(
            padding: (_screenSize.height > 900) ? EdgeInsets.only(left:24, right:24, top: 240) : EdgeInsets.only(left:24, right:24, top: 62),
            decoration: BoxDecoration(
              color: Color.fromRGBO(240, 240, 240, 1)
            ),
            child: Form(
              key: formKey,
              child: ListView(
                children: <Widget>[
                  Container(
                    margin: EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: _logoSize, height: _logoSize,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage("./images/logo.png")
                            )
                          ),
                        ),
                        Container(
                          margin: (_screenSize.height > 900) ? EdgeInsets.only(bottom: 12) : EdgeInsets.only(bottom: 5),
                          child: Text(
                            "SIGN UP",
                            style: TextStyle(
                              fontFamily: "ubuntu",
                              fontSize: 24,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),//logo and text
                  Container(
                    child: TextFormField(
                      controller: _firstnameCtr,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: "Firstname", labelText: "Firstname"
                      ),
                      validator: (value){
                        if(value.isEmpty) return "Firstname required";
                        else return null;
                      },
                      onEditingComplete: (){
                        FocusScope.of(_pageContext).requestFocus(_lastnameNode);
                      },
                    ),
                  ),

                  Container(
                    child: TextFormField(
                      controller: _lastnameCtr,
                      focusNode: _lastnameNode,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: "Lastname", labelText: "Lastname"
                      ),
                      validator: (value){
                        if(value.isEmpty) return "Lastname required";
                        else return null;
                      },
                      onEditingComplete: (){
                        FocusScope.of(_pageContext).requestFocus(_emailNode);
                      },
                    ),
                  ),

                  Container(
                    child: TextFormField(
                      controller: _emailCtr,
                      focusNode: _emailNode,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: "Email address", labelText: "Email"
                      ),
                      validator: (value){
                        if(value.isEmpty) return "Email address required";
                        else if(emExp.hasMatch(value)){
                          return null;
                        }
                        else return "Unaccepted email address";
                      },
                      onEditingComplete: (){
                        FocusScope.of(_pageContext).requestFocus(_phoneNode);
                      },
                    ),
                  ),//email address

                  Container(
                    child: TextFormField(
                      controller: _phoneCtr,
                      focusNode: _phoneNode,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: "Phone number", labelText: "Phone"
                      ),
                      validator: (value){
                        if(value.isEmpty) return "Phone number required";
                        else return null;
                      },
                      onEditingComplete: (){
                        FocusScope.of(_pageContext).requestFocus(_genderNode);
                      },
                    ),
                  ), //phone number 

                  Container(
                    margin: EdgeInsets.only(top:7, bottom: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          child: Text(
                            "Select Gender"
                          ),
                        ),
                        Container(
                          child: DropdownButton(
                            items: genderItem,
                            hint: Text(selectedGender),
                            focusNode: _genderNode,
                            isExpanded: true,
                            onChanged: (sel){
                              setState(() {
                                selectedGender=sel;
                              });
                              FocusScope.of(_pageContext).requestFocus(_dobNode);
                            }
                          ),
                        )
                      ],
                    )
                  ),

                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      focusNode: _dobNode,
                      readOnly: true,
                      controller: _dobCtr,
                      decoration: InputDecoration(
                        hintText: "Date of Birth",
                        labelText: "Date of Birth",
                      ),
                      onTap: ()async{
                        _selDOB=await showDatePicker(
                          context: _pageContext, 
                          initialDate: DateTime(2000), 
                          firstDate: DateTime(1900),
                          lastDate: tdy,
                          helpText: "Choose your date of birth",
                          fieldHintText: "Enter date here",
                          fieldLabelText: "Enter DOB here",
                        );
                        FocusScope.of(_pageContext).requestFocus(_submitNode);
                        _dobCtr.text= _selDOB.month.toString() + "/" + _selDOB.day.toString() + "/" + _selDOB.year.toString();
                      },
                      validator: (value){
                        if(value.isEmpty){
                          return "Date of birth required";
                        }
                        return null;
                      },
                    ),
                  ),

                  Container(
                    child: RaisedButton(
                      focusNode: _submitNode,
                      color: Color.fromARGB(73, 74, 174, 1),
                      textColor: Colors.white,
                      padding: EdgeInsets.only(top:12, bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                      ),
                      onPressed: (){
                        trySignup();
                      },
                      child: Text(
                        "Register"
                      ),
                    ),
                  )
                ],
              )
            )
          )// form body
        ),//the main form
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
  }//pagebody


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
  }//show toast

  Size _screenSize;
  double _logoSize;
  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    _screenSize.height < 640 ? _logoSize= 70 : _logoSize=100; 
    return MaterialApp(
      home: Scaffold(
        body: pageBody(),
      ),
    );
  }//page build

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

  successAlert(String emailStr, String fullnameStr){
    displayAlert(
      title: Center(child: Text("Successful"),), 
      content: Container(
        height: 150,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 100,
              margin: EdgeInsets.only(bottom: 7),
              child: AnimatedDrawing.svg(
                "./images/checked.svg",
                run: true,
                animationCurve: Curves.bounceOut,
                duration: Duration(
                  milliseconds: 1000
                ),
              ),
            ),
            Container(
              child: Text(
                "Registration was successful"
              ),
            )
          ],
        )
      ),
      action: [
        Container(
          width: MediaQuery.of(_pageContext).size.width - 12,
          child: RaisedButton(
            onPressed: ()async{
              Navigator.of(dlgCtx).pop();
              Navigator.of(_pageContext).push(
                MaterialPageRoute(
                  builder: (BuildContext ctx){
                    return ConfirmEmail(emailStr, fullnameStr);
                  }
                )
              );
            },
            child: Text(
              "CONTINUE"
            ),
          ),
        )
      ]
    );
  }//success alert

  @override
  void dispose() {
    super.dispose();
  }
}