import 'package:vm_service/vm_service.dart';
import 'package:vm_service_demo/vm_service_utils.dart';

const libraryPath = 'package:vm_service_demo/main.dart';
final utils = VmServerUtils(uriStr: 'ws://127.0.0.1:50904/lpPgNCZFa64=/ws');

late final VmService vms;
late final Isolate mainIsolate;
late final LibraryRef library;
late final Instance renderViewElement;

void main() async {
  vms = await utils.getVmService();
  mainIsolate = (await utils.findMainIsolate())!;
  library = (await utils.findLibrary(libraryPath))!;

  /// 私有方法，getter、setter 方法不能调用
  Response? renderViewElementResponse =
      await vms.invoke(mainIsolate.id!, library.id!, 'binding', []);
  renderViewElement = Instance.parse(renderViewElementResponse.json)!;

  /// 从 renderViewElement 深度优先遍历
  await depthFirst(renderViewElement.id!);
}

Future<void> depthFirst(String keyId) async {
  while (true) {
    final obj = await _depthFirst(keyId);
    if (obj == null) break;

    ///  List<Widget> 递归遍历
    if (obj.elements != null && obj.elements!.isNotEmpty) {
      for (final e in obj.elements!) {
        await depthFirst(e.id!);
      }
    }
    return;
  }
}

Future<Instance?> _depthFirst(String objId) async {
  Obj obj = await vms.getObject(mainIsolate.id!, objId);
  var element = Instance.parse(obj.json)!;

  while (true) {
    Response widgetResponse = await vms.invoke(mainIsolate.id!, element.id!, 'toString', []);
    final widgetRef = Instance.parse(widgetResponse.json);

    print(' ${widgetRef!.valueAsString}');
    if (widgetRef.valueAsString!.startsWith('MyHomePage')) {
      final _counter = await findCounterField(element);
      print('_counter = $_counter');
      return null;
    }

    final child = element.getFieldValueInstance('_child');

    if (child is InstanceRef) {
      obj = await vms.getObject(mainIsolate.id!, child.id!);
      element = Instance.parse(obj.json!)!;
    } else if (child == null) {
      final _children = element.getFieldValueInstance('_children');
      if (_children == null) return null;

      obj = await vms.getObject(mainIsolate.id!, _children.id!);
      element = Instance.parse(obj.json!)!;
      return element;
    } else {
      return null;
    }
  }
}

Future<String?> findCounterField(Instance element) async {
  final state = element.getFieldValueInstance('_state');
  final stateObj = await vms.getObject(mainIsolate.id!, state.id!);
  var _counterRef = Instance.parse(stateObj.json)!;

  final countRef = _counterRef.getFieldValueInstance('_counter');
  var counterObj = Instance.parse(countRef.json)!;

  return counterObj.valueAsString;
}
