import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../dbs.dart';
import '../globals.dart' as globals;

class EditWallProfile extends StatefulWidget{
  _EditWallProfile createState(){
    return _EditWallProfile();
  }
}

class _EditWallProfile extends State<EditWallProfile>{
  DBTables dbTables=DBTables();
  final formKey= GlobalKey<FormState>();
  Directory _appdir;
  Widget profileDp=Container();

  TextEditingController usernameCtr= TextEditingController();
  TextEditingController websiteCtr= TextEditingController();
  TextEditingController aboutCtr= TextEditingController();
  FocusNode websiteNode=FocusNode();
  FocusNode aboutNode= FocusNode();

  double toastOpacity=0;
  String toastText="";
  double toastPos=-30;

  Color updatePhotoLinkColor= Color.fromRGBO(255, 231, 146, 1);
  @override
  void initState() {
    super.initState();
    getLocalData();
  }//page init

  getLocalData()async{
    if(_appdir==null)
    _appdir=await getApplicationDocumentsDirectory();

    profileDp= Container(
      child: CircleAvatar(
        radius: 45,
        child: Text(
          globals.fullname.substring(0,1),
          style: TextStyle(
            color: Colors.white,
            fontSize: 32
          ),
        ),
      ),
    );

    Database con= await dbTables.myProfileCon();
    var result=await  con.rawQuery("select * from user_profile where status='active'");
    if(result.length == 1){
      var rw= result[0];
      File tmpDp= File(_appdir.path + "/wall_dir/" + rw["dp"]);
      if(await tmpDp.exists()){
        profileDp=Container(
          child: CircleAvatar(
            radius: 45,
            backgroundImage: FileImage(tmpDp),
          ),
        );
      }
      usernameCtr.text=rw["username"];
      websiteCtr.text=rw["website"];
      aboutCtr.text=rw["brief"];
      setState(() {
        
      });
    }
  }

  tryUpdateDP()async{
    setState(() {
      updatePhotoLinkColor=Color.fromRGBO(49, 108, 197, 1);
    });
    Future.delayed(
      Duration(milliseconds: 500),
      ()async{
        updatePhotoLinkColor= Color.fromRGBO(255, 231, 146, 1);
        setState(() {
          
        });
        
        try{
          File selPhoto= await FilePicker.getFile(
            type: FileType.image,
          );
          String selExt= selPhoto.path;
          List<String> brkPath= selExt.split(".");
          selExt= brkPath.last;
          List<String> allowedExts=["jpg", "png", "gif"];
          if(allowedExts.indexOf(selExt)<0){
            selExt="jpg";
          }
          
          showLoader(message: "Updating photo");
          String url= globals.globBaseUrl + "?process_as=update_wall_dp";
          http.Response resp= await http.post(
            url,
            body: {
              "user_id": globals.userId,
              "image": base64Encode(await selPhoto.readAsBytes()),
              "ext": selExt
            }
          );
          
          if(resp.statusCode == 200){
            var respObj= jsonDecode(resp.body);
            if(respObj["status"] == "success"){
              String serverPath= respObj["filename"];
              await selPhoto.copy(_appdir.path + "/wall_dir/" + serverPath);
              Database con= await dbTables.myProfileCon();

              //check for old files and delete if they exists
              var result1= await con.rawQuery("select * from user_profile where status='active'");
              if(result1.length == 1){
                var row= result1[0];
                File curDpFile= File(_appdir.path + "/wall_dir/" + row["dp"]);
                if(await curDpFile.exists()){
                  curDpFile.delete();
                }
              }
              //end check for old files and delete if they exists

              await con.execute("update user_profile set dp='$serverPath'");
              hideLoader();
              getLocalData();
              showToast(
                text: "Upload was successful!",
                persistDur: Duration(seconds: 7)
              );
            }
            else{
              hideLoader();
            }
          }
        }
        catch(ex){
          hideLoader();
        }
      }
    );
  }//tryupdate dp

  tryUpdateProfile()async{
    String url=globals.globBaseUrl + "?process_as=update_wall_profile";
    try{
      showLoader(
        message: "Updating ...",
      );
      http.Response resp=await http.post(
        url,
        body: {
          "user_id": globals.userId,
          "username": usernameCtr.text,
          "website": websiteCtr.text,
          "brief": aboutCtr.text
        }
      );
      if(resp.statusCode ==200){
        var respObj= jsonDecode(resp.body);
        if(respObj["status"] == "success"){
          Database con= await dbTables.myProfileCon();
          con.execute("update user_profile set username=?, website=?, brief=?", [usernameCtr.text, websiteCtr.text, aboutCtr.text]);
          hideLoader();
          showToast(
            text: "Update was successful!",
            persistDur: Duration(seconds: 3)
          );
          setState(() {
            
          });
        }
        else{
          hideLoader();
          showToast(
            text: respObj["message"],
            persistDur: Duration(seconds: 7)
          );
        }
      }
    }
    catch(ex){
      showToast(
        text: "Kindly check that your device is properly connected to the internet",
        persistDur: Duration(seconds: 7)
      );
      hideLoader();
    }
  }//try update profile

  BuildContext _pageContext;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    return Scaffold(
      backgroundColor: Color.fromRGBO(10, 10, 10, 1),
      appBar: AppBar(
        title: Text(
          "Profile Details",
          style: TextStyle(
            color: Colors.white
          ),
        ),
        backgroundColor: Color.fromRGBO(26, 26, 26, 1),
      ),
      body: Stack(
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(left:18, right:18),
            child: ListView(
              children: <Widget>[
                Container(
                  alignment: Alignment.center,
                  margin: EdgeInsets.only(top:24),
                  child: profileDp,
                ),
                Container(
                  margin: EdgeInsets.only(top:12, bottom: 32),
                  alignment: Alignment.center,
                  child: Material(
                    color: Colors.transparent,
                    child: InkResponse(
                      onTap: (){
                        tryUpdateDP();
                      },
                      child: Text(
                        "Update profile photo",
                        style: TextStyle(
                          color: updatePhotoLinkColor,
                          fontSize: 18
                        ),
                      ),
                    ),
                  ),
                ), //inkresponse to change profile photo

                Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              child: Text(
                                "Name",
                                style: TextStyle(
                                  color: Color.fromRGBO(240, 240, 240, 1),
                                  fontSize: 12
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top:7),
                              padding: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey
                                  )
                                )
                              ),
                              child: Text(
                                globals.fullname,
                                style: TextStyle(
                                  color: Colors.white
                                ),
                              ),
                            )
                          ],
                        ),
                      ), //user fullname not editable

                      Container(
                        margin: EdgeInsets.only(bottom: 24),
                        child: TextFormField(
                          controller: usernameCtr,
                          style: TextStyle(
                            color: Colors.white
                          ),
                          textInputAction: TextInputAction.next,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Username",
                            hintStyle: TextStyle(
                              color: Colors.white
                            ),
                            labelText: "Username",
                            labelStyle: TextStyle(
                              color: Colors.white
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color.fromRGBO(240, 240, 240, 1)
                              )
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color.fromRGBO(240, 240, 240, 1)
                              )
                            )
                          ),
                          onEditingComplete: (){
                            FocusScope.of(_pageContext).requestFocus(websiteNode);
                          },
                        ),
                      ),//username text feld

                      Container(
                        margin: EdgeInsets.only(bottom: 24),
                        child: TextFormField(
                          controller: websiteCtr,
                          focusNode: websiteNode,
                          keyboardType: TextInputType.url,
                          style: TextStyle(
                            color: Colors.white
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: "Website",
                            hintStyle: TextStyle(
                              color: Colors.white
                            ),
                            labelText: "Website",
                            labelStyle: TextStyle(
                              color: Colors.white
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color.fromRGBO(240, 240, 240, 1)
                              )
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color.fromRGBO(240, 240, 240, 1)
                              )
                            )
                          ),
                          onEditingComplete: (){
                            FocusScope.of(_pageContext).requestFocus(aboutNode);
                          },
                        ),
                      ), //website text field

                      Container(
                        child: TextFormField(
                          controller: aboutCtr,
                          focusNode: aboutNode,
                          style: TextStyle(
                            color: Colors.white
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: "Say something about yourself",
                            hintStyle: TextStyle(
                              color: Colors.white
                            ),
                            labelText: "About U",
                            labelStyle: TextStyle(
                              color: Colors.white
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color.fromRGBO(240, 240, 240, 1)
                              )
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color.fromRGBO(240, 240, 240, 1)
                              )
                            )
                          ),
                        ),
                      ), //brief about
                      Container(
                        margin: EdgeInsets.only(top:32),
                        width: double.infinity,
                        child: RaisedButton(
                          color: Color.fromRGBO(49, 108, 197, 1),
                          textColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: Colors.grey
                            ),
                            borderRadius: BorderRadius.circular(5)
                          ),
                          padding: EdgeInsets.only(
                            top:16, bottom: 16
                          ),
                          onPressed: (){
                            tryUpdateProfile();
                          },
                          child: Text(
                            "UPDATE",
                            style: TextStyle(
                              fontSize: 13
                            )
                          ),
                        ),
                      )//save btn
                    ],
                  ) 
                )
              ],
            )
          ),//page main content

          AnimatedPositioned(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOutQuad,
            bottom: toastPos,
            width: MediaQuery.of(context).size.width - 60,
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
          ),//implementation of the traditional android toast

        ],
      )
    );
  }//page build

  hideLoader(){
    Navigator.pop(dlgCtx2);
  }//hideloader

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
                      color: Color.fromRGBO(245,240,230, 1)
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
  }//showloader

  showToast({String text, Duration persistDur}){
    setState(() {
      toastText=text;
      toastOpacity=1;
      toastPos=200;
    });
    Future.delayed(
      persistDur,
      (){
        setState(() {
          toastOpacity=0;
          toastPos=-30;
        });
      }
    );
  }//show toast
}