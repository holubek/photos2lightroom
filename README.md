# Photos to Lightroom

**Keep Apple Photos as your master RAW library. Use Adobe Lightroom to edit your photographs.**

Photos to Lightroom is a small Mac app that helps you move selected originals from Apple Photos into a Lightroom editing workflow, then bring the finished photographs back to the same items in Photos. Your original RAW files stay in your Photos library.

It is for photographers who organize their collection in Apple Photos but want Lightroom's editing tools for selected shots.

## Disclaimer and backups

This tool is provided **“as is” and “as available,” without any warranty or guarantee**, express or implied, including warranties of merchantability, fitness for a particular purpose, and non-infringement. Use it entirely at your own risk. There is no guarantee that it will operate correctly or preserve your photos, videos, edits, metadata, or photo library.

To the fullest extent permitted by applicable law, the authors and contributors accept no liability for any claims, damages, or other losses arising from the use of, or inability to use, this tool, including accidental deletion, corruption, overwriting, loss of photos or other data, or damage to your photo library.

**Before using the app, make a separate backup of your Photos library and original files, and verify that you can restore it.** Test the workflow with copies of a few nonessential photos first. You are responsible for maintaining backups and checking the results of exports and returned edits.

## How it works

```text
Apple Photos              Lightroom                 Apple Photos
Your original RAWs  →     Edit exported copies  →    View finished photographs
                                                    Originals preserved
```

1. Select photographs in Apple Photos.
2. Export copies of their originals with Photos to Lightroom.
3. In **Lightroom (Local mode)**, navigate to `<user home>/PhotosToLR`, open your batch folder, edit the photographs, and export the finished JPEGs **into the same batch folder as the exported original files**.
4. Use Photos to Lightroom to apply the JPEGs to the original items in Photos.

For photographs, the returned JPEG becomes the edited version of the existing library item, rather than a separate imported photo. The app preserves the original RAW and any paired original JPEG in Photos. You can use Photos' **Revert to Original** command to remove the edit. See Apple's [guide to editing and reverting photos](https://support.apple.com/guide/photos/pht304c2ace6/mac).

The returned image contains the finished appearance of your Lightroom edit. Lightroom sliders, masks, and editing history do not transfer to Photos. Keep your Lightroom work if you want to adjust those settings later.

## What you need

- A Mac. The app's macOS deployment target is macOS 14 Sonoma or later; the Xcode version needed to open the project may require a newer macOS.
- Apple Photos with your original photographs available to export.
- Adobe Lightroom installed, with **Local mode** and access to its editing and export features.
- Xcode to build the app using the instructions below.
- Enough free disk space for exported originals and finished JPEGs.

The current workflow is for macOS, even though Xcode may also show iPhone or other destinations. Automatic opening targets Adobe Lightroom; Lightroom Classic compatibility has not been verified.

## Get the app running

These instructions build the app from its source code. “Build” simply means letting Xcode turn the project files into a Mac app. You do not need to write code or use Terminal.

1. **Install Xcode.** Get it from the Mac App Store, open it, and let it finish installing any required components. Use a recent version capable of opening this project. An older Xcode may report that the project format is unsupported.
2. **Download this project.** On the [repository page](https://github.com/holubek/photos2lightroom), click the green **Code** button, then **Download ZIP**.
3. **Unzip the download.** Open the extracted folder in Finder.
4. **Open the project.** Double-click `PhotosToLightroom.xcodeproj`.
5. **Choose your Mac.** In Xcode's top toolbar, choose the **PhotosToLightroom** scheme and **My Mac** as the run destination.
6. **Run it.** Choose **Product → Run**, or press **Command-R**. The first build may take a little while. When it finishes, the Photos to Lightroom window opens.

You can reopen this project and press **Command-R** whenever you want to use the app. For more help with Xcode's controls, see Apple's [build and run instructions](https://help.apple.com/xcode/mac/current/en.lproj/devdc0193470.html).

### Allow access to Photos

When prompted, allow the app to control Apple Photos and access your photo library. It needs these permissions to export your selection and apply the finished edits.

If you previously denied access, look under **System Settings → Privacy & Security**, in **Automation** and **Photos**, and enable access for the app. Full Photos access allows it to find the original items when returning edits.

## Edit your first batch

### 1. Select and export

Open Apple Photos and select the RAW photographs you want to edit. In Photos to Lightroom, click **Send Selected RAWs to Lightroom**.

The app creates a new folder inside `~/PhotosToLR` and reveals it in Finder. The `~` means your Mac home folder. To find it later, choose **Go → Go to Folder** in Finder and enter `~/PhotosToLR`.

Each batch has its own folder, with a numeric prefix and date in its name. Keep that folder in place until you have returned your edits.

For RAW+JPEG pairs, the app removes the extra exported JPEG copy when it recognizes the matching RAW. Both originals remain in Apple Photos.

### 2. Edit in Lightroom (Local mode)

The app tries to open Lightroom. If it does not open automatically, launch it yourself.

1. In Lightroom, open **Photos → Local** to browse files on your Mac.
2. Under **Browse**, navigate to **`<user home>/PhotosToLR`**. Your user home is the folder for your Mac login, usually shown with a house icon. The same location is written as `~/PhotosToLR` in the Finder instructions above.
3. Open the batch subfolder that Photos to Lightroom just created—the one revealed in Finder after export.
4. Select the exported RAW photographs and edit them in Lightroom.

Local mode lets you edit these files directly on your Mac without importing them into Lightroom's cloud library. You can add `PhotosToLR` to Lightroom's **Favorites** to find it quickly next time. See Adobe's [guide to editing locally stored photos](https://helpx.adobe.com/lightroom/desktop/add-import-and-capture-photos/access-photos.html).

### 3. Export finished JPEGs

Export your finished photographs from Lightroom as **JPEG** files, directly into the **same batch folder** as the exported RAWs.

Keep each original filename, changing only its extension. For example:

| Exported original | Finished Lightroom export |
| --- | --- |
| `IMG_1234.CR3` | `IMG_1234.jpg` |
| `DSC_5678.NEF` | `DSC_5678.jpg` |

Disable filename suffixes or renaming for RAW exports. Do not place the finished files in a subfolder. Keep only one matching JPEG per original; having both `IMG_1234.jpg` and `IMG_1234.jpeg` is ambiguous.

### 4. Return the edits to Photos

In Photos to Lightroom, click **Return Lightroom Edits to Photos**. The app matches the JPEGs to the original Photos items and applies the edits. Check the status message for any skipped files, then open Photos to review the results.

If a file is missing or incorrectly named, fix it and click the button again. The app retries unfinished items and skips items already applied in that batch.

**Finish returning a batch before sending a new selection.** The app remembers only the most recently exported batch, including after you close and reopen it. Sending a new selection replaces that tracking information.

## Other supported cases

- **JPEG originals:** If you export a standalone JPEG from Photos, name the finished edit with `-2` before the extension: `IMG_1234.jpg` → `IMG_1234-2.jpg`. This distinguishes the edit from the exported original. RAW+JPEG pairs use the RAW naming rule above.
- **Videos:** The return workflow accepts a matching MP4 export from a MOV original, such as `CLIP_1234.MOV` → `CLIP_1234.mp4`. It converts the edited MP4 to a QuickTime movie and applies it as a **reversible edit to the existing Photos item**, preserving its date, location, and original video. Use **Revert to Original** in Photos to discard the edit. Upright footage is rewrapped without recompression; footage with orientation transforms is rendered to bake in its orientation. For an MP4 original, keep the original file and export the edit with the `-2` suffix, such as `MVI_5000.MP4` → `MVI_5000-2.mp4`. The original MP4 is never selected as the returned edit.

## Current limitations

- This is a manual export, edit, and return workflow. It does not continuously synchronize Photos and Lightroom.
- Photo edits return as JPEGs. TIFF, PSD, DNG, and Lightroom editing instructions are not supported return formats.
- Exporting starts from the original files, so existing Photos adjustments are not carried into Lightroom.
- Once an item is successfully returned, clicking Return again does not apply another revision to it in the same batch.
- Files are matched by filename. Avoid photographs with identical base filenames in the same batch, even if they came from different cameras or folders.
- Export folders are not automatically cleaned up. Before removing one, check that your returned edits are correct and that Lightroom no longer needs the files in it.

## Troubleshooting

| What you see | What to check |
| --- | --- |
| “Select one or more photos” | Select the photographs in Apple Photos before clicking Send. |
| Lightroom does not open | Open it manually, choose **Photos → Local**, and browse to your batch folder inside `<user home>/PhotosToLR`. |
| “JPEG not found” | Follow the exact filename and folder shown in the app's message. Check for an added suffix or export subfolder. |
| “Multiple matching JPEG files” | Keep one finished JPEG for that original in the batch folder. |
| “Photos asset not found” | Check Photos permissions and make sure the original item is still available in your library. |
| “Send one or more photos … before applying edits” | Export a selection through this app first so it can remember which Photos items to update. |
| Xcode cannot open the project | Check whether Xcode needs updating to support the project's format. |
| Xcode tries to build for an iPhone or simulator | Change the run destination to **My Mac**. |

## Privacy

The app does not ask for an Apple or Adobe account password and contains no analytics or custom upload service. It stores batch tracking information locally in its preferences, including exported file paths, original filenames, and Photos identifiers.

Apple Photos may download originals from iCloud when needed. Any cloud syncing performed by Photos or Lightroom follows your settings in those applications.

## Feedback and contributions

Report problems or suggest improvements in [GitHub Issues](https://github.com/holubek/photos2lightroom/issues). Include your macOS version, Lightroom version, file type, and the steps that led to the problem. Remove personal filenames, folder paths, and private photos from screenshots or error messages before posting.

Contributions that improve the workflow or make setup easier for photographers are welcome.
