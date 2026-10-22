import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)

manifest_path = Path("android/app/src/main/AndroidManifest.xml")
tree = ET.parse(manifest_path)
root = tree.getroot()

permissions = {
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.SCHEDULE_EXACT_ALARM",
}
existing_permissions = {
    element.get(f"{{{ANDROID_NS}}}name")
    for element in root.findall("uses-permission")
}
for permission in sorted(permissions - existing_permissions):
    ET.SubElement(
        root,
        "uses-permission",
        {f"{{{ANDROID_NS}}}name": permission},
    )

application = root.find("application")
if application is None:
    raise RuntimeError("Android manifest does not define an application element")
application.set(f"{{{ANDROID_NS}}}label", "Barbería YASSER")

receivers = {
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver": [],
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver": [
        "android.intent.action.BOOT_COMPLETED",
        "android.intent.action.MY_PACKAGE_REPLACED",
    ],
}
existing_receivers = {
    receiver.get(f"{{{ANDROID_NS}}}name"): receiver
    for receiver in application.findall("receiver")
}

for receiver_name, actions in receivers.items():
    receiver = existing_receivers.get(receiver_name)
    if receiver is None:
        receiver = ET.SubElement(
            application,
            "receiver",
            {
                f"{{{ANDROID_NS}}}name": receiver_name,
                f"{{{ANDROID_NS}}}exported": "false",
            },
        )
    if actions and receiver.find("intent-filter") is None:
        intent_filter = ET.SubElement(receiver, "intent-filter")
        for action in actions:
            ET.SubElement(
                intent_filter,
                "action",
                {f"{{{ANDROID_NS}}}name": action},
            )

tree.write(manifest_path, encoding="utf-8", xml_declaration=True)

gradle_path = Path("android/app/build.gradle.kts")
gradle = gradle_path.read_text(encoding="utf-8")

if "isCoreLibraryDesugaringEnabled = true" not in gradle:
    compile_options = "    compileOptions {\n"
    if compile_options not in gradle:
        raise RuntimeError(f"Could not find compileOptions in {gradle_path}")
    gradle = gradle.replace(
        compile_options,
        compile_options + "        isCoreLibraryDesugaringEnabled = true\n",
        1,
    )

desugaring_dependency = (
    'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
)
if desugaring_dependency not in gradle:
    dependencies_block = "dependencies {\n"
    if dependencies_block in gradle:
        gradle = gradle.replace(
            dependencies_block,
            dependencies_block + f"    {desugaring_dependency}\n",
            1,
        )
    else:
        gradle += f"\ndependencies {{\n    {desugaring_dependency}\n}}\n"

gradle_path.write_text(gradle, encoding="utf-8")
