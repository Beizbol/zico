interface FaviconOptions {
  readonly path?: string;
  readonly appName?: string;
  readonly appShortName?: string;
  readonly appDescription?: string;
  readonly developerName?: string;
  readonly developerURL?: string;
  readonly cacheBustingQueryParam?: string | null;
  readonly dir?: string;
  readonly lang?: string;
  readonly background?: string;
  readonly theme_color?: string;
  readonly appleStatusBarStyle?: string;
  readonly display?: string;
  readonly orientation?: string;
  readonly scope?: string;
  readonly start_url?: string;
  readonly version?: string;
  readonly pixel_art?: boolean;
  readonly loadManifestWithCredentials?: boolean;
  readonly manifestRelativePaths?: boolean;
  readonly manifestMaskable?: boolean | string | Buffer | (string | Buffer)[];
  readonly preferRelatedApplications?: boolean;
  readonly relatedApplications?: Application[];
  readonly icons?: Record<PlatformName, IconOptions | boolean | string[]>;
  readonly files?: Record<PlatformName, FileOptions>;
  readonly shortcuts?: ShortcutOptions[];
  readonly output?: OutputOptions;
}

export const defaultOptions: FaviconOptions = {
  path: "/",
  // appName: null,
  // appShortName: null,
  // appDescription: null,
  // developerName: null,
  // developerURL: null,
  // cacheBustingQueryParam: null,
  dir: "auto",
  lang: "en-US",
  background: "#fff",
  theme_color: "#fff",
  appleStatusBarStyle: "black-translucent",
  display: "standalone",
  orientation: "any",
  start_url: "/?homescreen=1",
  version: "1.0",
  pixel_art: false,
  loadManifestWithCredentials: false,
  manifestRelativePaths: false,
  manifestMaskable: false,
  preferRelatedApplications: false,
  icons: {
    android: true,
    appleIcon: true,
    appleStartup: true,
    favicons: true,
    windows: true,
    yandex: true,
  },
  output: {
    images: true,
    files: true,
    html: true,
  },
};

type RawImage = { data: Buffer; info: sharp.OutputInfo };
type SourceImage = { data: Buffer; metadata: sharp.Metadata };

const HEADER_SIZE = 6;
const DIRECTORY_SIZE = 16;
const COLOR_MODE = 0;
const BITMAP_SIZE = 40;

function createHeader(n: number) {
  const buf = Buffer.alloc(HEADER_SIZE);

  buf.writeUInt16LE(0, 0);
  buf.writeUInt16LE(1, 2);
  buf.writeUInt16LE(n, 4);
  return buf;
}

function createDirectory(image: RawImage, offset: number) {
  const buf = Buffer.alloc(DIRECTORY_SIZE);
  const { width, height } = image.info;
  const size = width * height * 4 + BITMAP_SIZE;
  const bpp = 32;

  buf.writeUInt8(width === 256 ? 0 : width, 0);
  buf.writeUInt8(height === 256 ? 0 : height, 1);
  buf.writeUInt8(0, 2);
  buf.writeUInt8(0, 3);
  buf.writeUInt16LE(1, 4);
  buf.writeUInt16LE(bpp, 6);
  buf.writeUInt32LE(size, 8);
  buf.writeUInt32LE(offset, 12);
  return buf;
}

function createBitmap(image: RawImage, compression: number) {
  const buf = Buffer.alloc(BITMAP_SIZE);
  const { width, height } = image.info;

  buf.writeUInt32LE(BITMAP_SIZE, 0);
  buf.writeInt32LE(width, 4);
  buf.writeInt32LE(height * 2, 8);
  buf.writeUInt16LE(1, 12);
  buf.writeUInt16LE(32, 14);
  buf.writeUInt32LE(compression, 16);
  buf.writeUInt32LE(width * height, 20);
  buf.writeInt32LE(0, 24);
  buf.writeInt32LE(0, 28);
  buf.writeUInt32LE(0, 32);
  buf.writeUInt32LE(0, 36);
  return buf;
}

function createDib(image: RawImage) {
  const { width, height } = image.info;
  const imageData = image.data;
  const buf = Buffer.alloc(width * height * 4);

  for (let y = 0; y < height; ++y) {
    for (let x = 0; x < height; ++x) {
      const offset = (y * width + x) * 4;
      const r = imageData.readUInt8(offset);
      const g = imageData.readUInt8(offset + 1);
      const b = imageData.readUInt8(offset + 2);
      const a = imageData.readUInt8(offset + 3);
      const pos = (height - y - 1) * width + x;

      buf.writeUInt8(b, pos * 4);
      buf.writeUInt8(g, pos * 4 + 1);
      buf.writeUInt8(r, pos * 4 + 2);
      buf.writeUInt8(a, pos * 4 + 3);
    }
  }
  return buf;
}

function toIco(images: RawImage[]) {
  const header = createHeader(images.length);
  let arr = [header];

  let offset = HEADER_SIZE + DIRECTORY_SIZE * images.length;

  const bitmaps = images.map((image) => {
    const bitmapHeader = createBitmap(image, COLOR_MODE);
    const dib = createDib(image);

    return Buffer.concat([bitmapHeader, dib]);
  });

  for (let i = 0; i < images.length; ++i) {
    const image = images[i];
    const bitmap = bitmaps[i];

    const dir = createDirectory(image, offset);

    arr.push(dir);
    offset += bitmap.length;
  }

  arr = [...arr, ...bitmaps];

  return Buffer.concat(arr);
}

const ICONS_OPTIONS: (NamedIconOptions & OptionalMixin)[] = [
  { name: "favicon.ico", ...transparentIcons(16, 24, 32, 48, 64) },
];

class FaviconsPlatform extends Platform {
  constructor(options: FaviconOptions) {
    super(
      options,
      uniformIconOptions(options, options.icons.favicons, ICONS_OPTIONS),
    );
  }
}

interface IconOptions {
  readonly sizes: IconSize[];
  readonly offset?: number;
  readonly background?: string | boolean;
  readonly transparent: boolean;
  readonly rotate: boolean;
  readonly purpose?: string;
  readonly pixelArt?: boolean;
}

function transparentIcons(...sizes: number[]): IconOptions {
  return {
    sizes: sizes.map((size) => ({ width: size, height: size })),
    offset: 0,
    background: false,
    transparent: true,
    rotate: false,
  };
}

function createBlankImage(
  width: number,
  height: number,
  background?: string,
): sharp.Sharp {
  const transparent = !background || background === "transparent";

  let image = sharp({
    create: {
      width,
      height,
      channels: transparent ? 4 : 3,
      background: transparent ? "#00000000" : background,
    },
  });

  if (transparent) {
    image = image.ensureAlpha();
  }
  return image;
}

interface IconPlaneOptions {
  readonly width: number;
  readonly height: number;
  readonly offset: number;
  readonly pixelArt: boolean;
  readonly background?: string;
  readonly transparent: boolean;
  readonly rotate: boolean;
}

async function createPlane(
  sourceset: SourceImage[],
  options: IconPlaneOptions,
): Promise<sharp.Sharp> {
  const offset =
    Math.round(
      (Math.max(options.width, options.height) * options.offset) / 100,
    ) || 0;
  const width = options.width - offset * 2;
  const height = options.height - offset * 2;

  const source = bestSource(sourceset, width, height);
  const image = await resize(source, width, height, options.pixelArt);

  let pipeline = createBlankImage(
    options.width,
    options.height,
    options.background,
  ).composite([{ input: image, left: offset, top: offset }]);

  if (options.rotate) {
    const degrees = 90;
    pipeline = pipeline.rotate(degrees);
  }

  return pipeline;
}

interface FaviconImage {
  readonly name: string;
  readonly contents: Buffer;
}

function toRawImage(pipeline: sharp.Sharp): Promise<RawImage> {
  return pipeline
    .toColorspace("srgb")
    .raw({ depth: "uchar" })
    .toBuffer({ resolveWithObject: true });
}

function asString(arg: unknown): string | undefined {
  return typeof arg === "string" || arg instanceof String
    ? arg.toString()
    : undefined;
}

async function createFavicon(
  sourceset: SourceImage[],
  name: string,
  iconOptions: IconOptions,
): Promise<FaviconImage> {
  const properties = iconOptions.sizes.map((size) => ({
    ...size,
    offset: iconOptions.offset ?? 0,
    pixelArt: iconOptions.pixelArt ?? false,
    background: asString(iconOptions.background),
    transparent: iconOptions.transparent,
    rotate: iconOptions.rotate,
  }));

  const images = await Promise.all(
    properties.map((props) => createPlane(sourceset, props).then(toRawImage)),
  );
  const contents = toIco(images);
  return { name, contents };

}