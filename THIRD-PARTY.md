# Third-party source and assets

This derivative application is distributed under GNU GPL version 3. See LICENSE.

- udevs / locsim: `Vendor/locsim/LSMGPXParserDelegate.h`, `.m`, and `macros.h`, copyright 2021 udevs, GPLv3. Imported unchanged from commit `7f7010de6061896237a98de950df715aa1fd61b9`: https://github.com/udevsharold/locsim
- The system scenario invocation was researched from locsim, Geranium (c22dev), and locsim-gui (copyright 2026 KeystoneLabs Limited); these upstream projects use GPLv3. https://github.com/c22dev/Geranium and https://github.com/klab-admin/locsim-gui
- Leaflet 1.9.4, BSD-2-Clause. Its license is included under `Resources/web/vendor/Leaflet-LICENSE.txt`. https://leafletjs.com
- Map imagery is loaded on demand from Esri World Imagery or OpenStreetMap. Attribution is rendered in the map. No offline tile download is included.

Map routes entered in the app remain in its local web storage. GPX export is initiated by the user through the iOS share sheet. The source bundle includes no personal route, device identifier, account credential or pairing file.
