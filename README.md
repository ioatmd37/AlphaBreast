# AlphaBreast Scan (iOS, alpha)

แอป iOS สำหรับสแกนลำตัวส่วนหน้าด้วย LiDAR จุด landmark 9 จุด และส่งออกไฟล์ `.obj`/`.ply` + `.json`
ให้หน้า Scan ของ [augsizer](https://augsizer.pages.dev/#scan) เปิดต่อ สเปกอยู่ที่
[`docs/ios-alphabreast-scan.md`](docs/ios-alphabreast-scan.md)

สถานะ: เขียนครบตั้งแต่สแกนจนถึงส่งออก (M0–M2 ตามสเปก) แต่ยังไม่เคยรันบนเครื่องจริง
ต้องทดสอบบน iPhone/iPad ที่มี LiDAR ตาม M0 ก่อน

## เริ่มต้น

ต้องมี macOS พร้อม Xcode 16 ขึ้นไป และ [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # ใส่ Team ID
xcodegen generate
open AlphaBreastScan.xcodeproj
```

ต้องรันบนเครื่องจริงที่มี LiDAR เพราะ Simulator ไม่มี ARKit scene reconstruction
ไฟล์ `.xcodeproj`, `Info.plist` และ entitlements สร้างจาก `project.yml` จึงไม่อยู่ใน git
แก้การตั้งค่าที่ `project.yml` แล้วรัน `xcodegen generate` ใหม่

### รหัส alpha (ไม่บังคับ)

แอปเก็บเฉพาะ SHA-256 ของรหัส ใส่ใน `Config/Local.xcconfig` (ไฟล์นี้ไม่เข้า git):

```sh
printf %s 'รหัส' | shasum -a 256
```

ถ้าเว้นว่าง แอปจะไม่ถามรหัส และใช้รายชื่อผู้ทดสอบของ TestFlight แทน
รหัสสั้นเดาจาก hash ได้ จึงเป็นแค่การล็อกแบบอ่อนตามสเปก

## โครงสร้าง

```
project.yml                 XcodeGen: target, Info.plist, entitlements
Config/                     xcconfig (Local.xcconfig สำหรับ Team ID และ hash รหัส)
Packages/ScanCore/          ตรรกะที่ไม่ขึ้นกับ Apple framework ทดสอบได้บน Linux
  Sources/ScanCore/
    Landmarks.swift         key 9 จุด + จุดอ้างอิง (ตรงกับ ScanAlpha.tsx)
    Measurements.swift      ค่าวัด, ตรวจ scale 10 cm ±3 mm, เตือนจุดสลับข้าง
    MeshProcessing.swift    รวมจุดซ้ำ, ตัดกรอบ, เก็บชิ้นใหญ่สุด, ลดเหลือ ≤100k สามเหลี่ยม
    BodyAlignment.swift     จัดแกนส่งออกจาก NAC
    SweepTracker.swift      แถบความครอบคลุม 180°
    ScanDocument.swift      ไฟล์ .json schema alphabreast-scan/1
    MeshWriters.swift       ไฟล์ .obj และ .ply
AlphaBreastScan/
  App/                      จุดเริ่ม, Face ID, รหัส alpha, บังหน้าจอใน app switcher
  Guide/                    แผนภาพ marker, รายการตรวจ, ความยินยอม
  Capture/                  ARSession + ARMeshAnchor, แถบความครอบคลุม
  Processing/               ตรวจผล, ปรับกรอบตัด, ตัวแสดงโมเดล SceneKit
  Landmarks/                แตะจุดบนโมเดล, ย้อนกลับ, แก้จุด
  Export/                   ค่าวัด, เขียนไฟล์, share sheet, ลบไฟล์
```

ทดสอบ ScanCore:

```sh
swift test --package-path Packages/ScanCore
```

CI (`.github/workflows/ci.yml`) รันเทสต์ ScanCore บน Linux และ build แอปแบบไม่ sign บน macOS

## ลำดับการใช้งาน

ปลดล็อก → เตรียมผู้ป่วยและบันทึกความยินยอม → สแกน → ตรวจผลและปรับกรอบ → จุด landmark → ค่าวัดและส่งออก

**การสแกน**: ยืนตรงหน้าผู้ป่วย เล็งกากบาทที่กลางกระดูกอกระดับหัวนม แล้วกดเริ่ม จุดนี้กลายเป็นจุดกำเนิดและกำหนดทิศด้านหน้า
จากนั้นเดินไปด้านขวาของผู้ป่วยแล้วโค้งผ่านด้านหน้าไปด้านซ้าย แถบด้านล่างแบ่งส่วนโค้ง 180° เป็น 18 ช่อง
(ขั้นเล็งจากด้านหน้าเพิ่มจากโปรโตคอลในสเปก เพื่อให้ได้แกนและจุดอ้างอิงของกรอบตัด)

## ระบบพิกัดและไฟล์ส่งออก

- หน่วยเมตร, +Y ขึ้น (ตามแรงโน้มถ่วง), +Z ออกจากหน้าอก, +X ไปทางซ้ายของผู้ป่วย
- ตอนส่งออก แกน X ถูกจัดใหม่ให้ขนานกับเส้น nR → nL ในแนวราบ จุดกำเนิดอยู่ที่กึ่งกลาง NAC ทั้งสองข้าง
  ถอยไปที่ความลึกของ medR/medL
- `.json` เรียง key ตามสเปก ทศนิยม 4 ตำแหน่ง (0.1 mm) และเพิ่ม `consentAt` (เวลาที่ยินยอม ไม่มีตัวตน)
  ถ้าเว็บตรวจ key แบบเข้มงวดต้องรองรับฟิลด์นี้ หรือเอาออกจาก `ScanDocument.swift`
- `.obj` มี normal ต่อ vertex, `.ply` เป็น ASCII ทั้งสองไฟล์เขียนเองใน ScanCore ไม่ใช้ ModelIO
  เพื่อให้ควบคุมรูปแบบและทดสอบได้

## ความเป็นส่วนตัว (ข้อ 9 ในสเปก)

| ข้อกำหนด | ที่ทำในโค้ด |
|---|---|
| ไม่เรียกเครือข่าย | ไม่มีโค้ดเครือข่ายเลย |
| ไม่ลง Photos / ไม่ซิงก์ iCloud | ไม่ขอสิทธิ์ Photos, ตัด "Save Image" ออกจาก share sheet, ตั้ง `isExcludedFromBackup` |
| Data Protection `complete` | entitlement `default-data-protection` + `.completeFileProtection` ทุกไฟล์ |
| ลบหลังส่งออกหรือเกิน 24 ชม. | ข้อมูลสแกนอยู่ในหน่วยความจำ เขียนไฟล์เฉพาะตอนส่งออกแล้วลบเมื่อปิด share sheet, ล้างไฟล์เก่ากว่า 24 ชม. ตอนเปิดแอป |
| ปลดล็อกทุกครั้ง | `LocalAuthentication` ตอนเปิดและทุกครั้งที่กลับจากพื้นหลัง |
| บังหน้าจอใน app switcher | ครอบหน้าจอเมื่อ scene ไม่ active |
| ความยินยอมก่อนสแกน | ต้องบันทึกก่อนเริ่มสแกน, เก็บเฉพาะเวลา, ล้างเมื่อเริ่มผู้ป่วยรายใหม่ |

## ยังไม่ได้ทำ / ต้องทดสอบ

- ยังไม่เคยรันบนเครื่องจริง ค่ากรอบตัดเริ่มต้นใน `CropBox.torsoDefault` เป็นค่าประมาณ ต้องปรับจากการสแกนหุ่น (M0)
- ความละเอียด mesh ของ ARKit อาจไม่พอสำหรับรูปเต้า (ความเสี่ยงข้อ 12) ถ้าย้ายไปทางเลือก B
  ให้เปลี่ยนเฉพาะ `Capture/` รูปแบบไฟล์ส่งออกยังเหมือนเดิม
- แถบความครอบคลุมนับตามมุมรอบตัวเท่านั้น ยังไม่นับมุมก้มเงย
- ฝั่งเว็บยังไม่รับไฟล์ `.json`
