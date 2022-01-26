// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:developer';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:vm_service/utils.dart';

class VmServerUtils {
  static VmServerUtils? _instance;
  bool _enable = false;
  VmService? _vmService;
  VM? _vm;
  String uriStr;

  factory VmServerUtils({String uriStr = ''}) {
    _instance ??= VmServerUtils._(uriStr);
    return _instance!;
  }

  bool get isEnable => _enable;

  VmServerUtils._(this.uriStr) {
    _enable = true;
  }

  Future<String?> getObservatoryUri() async {
    ServiceProtocolInfo serviceProtocolInfo = await Service.getInfo();
    Uri url = convertToWebSocketUrl(serviceProtocolUrl: serviceProtocolInfo.serverUri!);
    return url.toString();
  }

  ///VmService
  Future<VmService> getVmService() async {
    final uri = uriStr.isEmpty ? await getObservatoryUri() : uriStr;

    _vmService ??= await vmServiceConnectUri(uri!).catchError((error) {
      if (error is SocketException) {
        print('vm_service connection refused, Try:');
      }
    });
    return _vmService!;
  }

  Future<VM?> getVM() async {
    _vm ??= await (await getVmService()).getVM();
    return _vm;
  }

  ///find a [Library] on [Isolate]
  Future<LibraryRef?> findLibrary(String uri) async {
    Isolate? mainIsolate = await findMainIsolate();
    if (mainIsolate != null) {
      final libraries = mainIsolate.libraries;
      if (libraries != null) {
        for (int i = 0; i < libraries.length; i++) {
          var lib = libraries[i];
          if (lib.uri == uri) {
            return lib;
          }
        }
      }
    }
    return null;
  }

  ///find main Isolate in VM
  Future<Isolate?> findMainIsolate() async {
    IsolateRef? ref;
    final vm = await getVM();
    if (vm == null) return null;
    vm.isolates?.forEach((isolate) {
      if (isolate.name == 'main') {
        ref = isolate;
      }
    });
    final vms = await getVmService();
    if (ref?.id != null) {
      return vms.getIsolate(ref!.id!);
    }
    return null;
  }
}

extension MyInstance on Instance {
  BoundField? getField(String name) {
    if (fields == null) return null;
    for (int i = 0; i < fields!.length; i++) {
      var field = fields![i];
      if (field.decl?.name == name) {
        return field;
      }
    }
    return null;
  }

  dynamic getFieldValueInstance(String name) {
    final field = getField(name);
    if (field != null) {
      return field.value;
    }
    return null;
  }
}


extension MyString on String {
  Future<Instance> strIdToInstance(VmService vms, String mainId) async {
    Obj obj = await vms.getObject(mainId, mainId);
    return Instance.parse(obj.json)!;
  }
}