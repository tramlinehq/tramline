android {
  compileSdk = libs.versions.android.sdk.compile.get().toInt()
  sourceSets["main"].manifest.srcFile("src/androidMain/AndroidManifest.xml")

  defaultConfig {
    minSdk = libs.versions.android.sdk.min.get().toInt()
    targetSdk = libs.versions.android.sdk.target.get().toInt()

    versionCode =
      if (project.properties["VERSION_CODE"] != null) {
        (project.properties["VERSION_CODE"] as String).toInt()
      } else {
        1
      }

    versionName = "1.2.0"
  }
}
