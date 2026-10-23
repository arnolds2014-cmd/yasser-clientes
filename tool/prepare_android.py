import xml.etree.ElementTree as ET
from pathlib import Path
import shutil

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
permission_elements = {}
for element in root.findall("uses-permission"):
    permission_elements[element.get(f"{{{ANDROID_NS}}}name")] = element
    root.remove(element)

application = root.find("application")
if application is None:
    raise RuntimeError("Android manifest does not define an application element")
application.set(f"{{{ANDROID_NS}}}label", "Barbería YASSER")

for permission in permissions:
    if permission not in permission_elements:
        permission_elements[permission] = ET.Element(
            "uses-permission",
            {f"{{{ANDROID_NS}}}name": permission},
        )

for application_index, permission in enumerate(sorted(permission_elements)):
    root.insert(application_index, permission_elements[permission])

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
    if actions:
        intent_filter = receiver.find("intent-filter")
        if intent_filter is None:
            intent_filter = ET.SubElement(receiver, "intent-filter")
        existing_actions = {
            action.get(f"{{{ANDROID_NS}}}name")
            for action in intent_filter.findall("action")
        }
        for action in actions:
            if action not in existing_actions:
                ET.SubElement(
                    intent_filter,
                    "action",
                    {f"{{{ANDROID_NS}}}name": action},
                )

ET.indent(tree, space="    ")
tree.write(manifest_path, encoding="utf-8", xml_declaration=True)

gradle_path = Path("android/app/build.gradle.kts")
gradle = gradle_path.read_text(encoding="utf-8")

google_services_plugin = 'id("com.google.gms.google-services")'
if google_services_plugin not in gradle:
    application_plugin = '    id("com.android.application")\n'
    if application_plugin not in gradle:
        raise RuntimeError(f"Could not find Android application plugin in {gradle_path}")
    gradle = gradle.replace(
        application_plugin,
        application_plugin + f"    {google_services_plugin}\n",
        1,
    )

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

settings_path = Path("android/settings.gradle.kts")
settings = settings_path.read_text(encoding="utf-8")
google_services_plugin_declaration = (
    'id("com.google.gms.google-services") version "4.4.2" apply false'
)
if google_services_plugin_declaration not in settings:
    android_plugin_line = next(
        (
            line
            for line in settings.splitlines()
            if line.strip().startswith('id("com.android.application")')
        ),
        None,
    )
    if android_plugin_line is None:
        raise RuntimeError(f"Could not find Android application plugin in {settings_path}")
    settings = settings.replace(
        android_plugin_line,
        f"{android_plugin_line}\n    {google_services_plugin_declaration}",
        1,
    )
settings_path.write_text(settings, encoding="utf-8")

icon_source = Path("tool/android_icons")
resource_dir = Path("android/app/src/main/res")
for icon_dir in icon_source.glob("mipmap-*"):
    source_icon = icon_dir / "ic_launcher.png"
    if source_icon.is_file():
        destination_dir = resource_dir / icon_dir.name
        destination_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_icon, destination_dir / source_icon.name)
