{-# LANGUAGE OverloadedStrings #-}

import  Data.List (isSuffixOf)
import  Data.Map qualified as Map
import  Hakyll
import  Prelude
import  Skylighting.Types (Style (..), TokenStyle (..), Color, ToColor (..), TokenType (..), defStyle)
import  Text.Pandoc.Definition (Block (CodeBlock), Pandoc)
import  Text.Pandoc.Highlighting
import  Text.Pandoc.Options (WriterOptions (..))
import  Text.Pandoc.Walk (walk)

main :: IO ()
main = hakyll  do
    match "images/*"  do
        route   idRoute
        compile copyFileCompiler

    match "files/*"  do
        route   idRoute
        compile copyFileCompiler

    match "css/*"  do
        route   idRoute
        compile compressCssCompiler

    match "fonts/*"  do
        route   idRoute
        compile copyFileCompiler

    match "CNAME"  do
        route   idRoute
        compile copyFileCompiler

    match "robots.txt"  do
        route   idRoute
        compile copyFileCompiler

    match (fromList ["about.rst", "contact.markdown"])  do
        route   $ setExtension "html"
        compile $ pandocCompiler'
            >>= loadAndApplyTemplate "templates/default.html" siteCtx
            >>= relativizeUrls

    match "cv.html"  do
        route idRoute
        compile $ getResourceBody
            >>= loadAndApplyTemplate "templates/default.html" siteCtx
            >>= relativizeUrls

    match "posts/*"  do
        route $ setExtension "html"
        compile $ pandocCompiler'
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"]  do
        route idRoute
        compile  do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archive"             `mappend`
                    constField "description" "Every post on mrcjkb.dev, newest first." `mappend`
                    constField "active_archive" "true"      `mappend`
                    constField "language" "html"            `mappend`
                    siteCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    create ["css/syntax.css"] do
      route idRoute
      compile  do
        makeItem $ styleToCss pandocCodeStyle

    create ["atom.xml"] do
      route idRoute
      compile $ mkFeed renderAtom

    create ["rss.xml"] do
      route idRoute
      compile $ mkFeed renderRss


    match "index.html"  do
        route idRoute
        compile  do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    siteCtx

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    create ["sitemap.xml"]  do
        posts <- getMatches "posts/*"
        let postPaths = toHtml . toFilePath <$> posts
            staticPaths :: [String]
            staticPaths = ["about.html", "contact.html", "cv.html", "archive.html"]
            urls = siteUrl <> "/" : (((siteUrl <>) . ("/" <>)) <$> (postPaths <> staticPaths))
        route idRoute
        compile . makeItem $ sitemap urls

    match "templates/*" $ compile templateBodyCompiler
  where
    siteUrl :: String
    siteUrl = "https://mrcjkb.dev"

    sitemap :: [String] -> String
    sitemap urls =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        <> "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"
        <> mconcat ((\url -> "  <url><loc>" <> url <> "</loc></url>\n") <$> urls)
        <> "</urlset>\n"

    toHtml :: String -> String
    toHtml path = stripSuffix' ".markdown" path <> ".html"

    stripSuffix' :: Eq a => [a] -> [a] -> [a]
    stripSuffix' suffix str
      | suffix `isSuffixOf` str = take (length str - length suffix) str
      | otherwise = str


--------------------------------------------------------------------------------

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    siteCtx

siteCtx :: Context String
siteCtx =
    bufferNameField `mappend`
    defaultContext

bufferNameField :: Context String
bufferNameField = field "buffername" \item ->
    pure . bufferName . toFilePath $ itemIdentifier item

bufferName :: String -> String
bufferName "index.html" = "~/mrcjkb.dev"
bufferName "cv.html" = "cv.pdf"
bufferName path
  | markdown `isSuffixOf` path = take (length path - length markdown) path <> ".md"
  | otherwise = path
  where
    markdown = ".markdown" :: String

pandocCodeStyle :: Style
pandocCodeStyle = catppuccinMocha

pandocCompiler' :: Compiler (Item String)
pandocCompiler' =
  pandocCompilerWithTransform
    defaultHakyllReaderOptions
    defaultHakyllWriterOptions
      { writerHighlightStyle   = Just pandocCodeStyle
      }
    addLineNumbers

addLineNumbers :: Pandoc -> Pandoc
addLineNumbers = walk addNumberLines
  where
    addNumberLines :: Block -> Block
    addNumberLines (CodeBlock (identifier, classes, attrs) code) =
      CodeBlock (identifier, "numberLines" : classes, attrs) code
    addNumberLines block = block

type FeedRenderer = FeedConfiguration -> Context String -> [Item String] -> Compiler (Item String)

mkFeed :: FeedRenderer -> Compiler (Item String)
mkFeed render = do
    let feedCtx = postCtx `mappend` bodyField "description"
        feedConfiguration = FeedConfiguration
          { feedTitle       = "mrcjkb.dev"
          , feedDescription = "Marc Jakobi on Haskell, Nix, Neovim and renewable energy systems."
          , feedAuthorName  = "Marc Jakobi"
          , feedAuthorEmail = "marc@jakobi.dev"
          , feedRoot        = "https://mrcjkb.dev"
          }
    posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "posts/*" "content"
    render feedConfiguration feedCtx posts

catppuccinMocha :: Style
catppuccinMocha = Style{
    backgroundColor = Nothing
  , defaultColor = Nothing
  , lineNumberColor = color 0xcdd6f4
  , lineNumberBackgroundColor = Nothing
  , tokenStyles = Map.fromList
    [ (KeywordTok, defStyle{ tokenColor = color 0xcba6f7 })
    , (FunctionTok, defStyle{ tokenColor = color 0x89b4fa })
    , (OperatorTok, defStyle{ tokenColor = color 0x74c7ec })
    , (CharTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (StringTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (CommentTok, defStyle{ tokenColor = color 0x9399b2 })
    , (OtherTok, defStyle{ tokenColor = color 0xcdd6f4 })
    , (AlertTok, defStyle{ tokenColor = color 0xf38ba8 })
    , (ErrorTok, defStyle{ tokenColor = color 0xf38ba8, tokenBold = True })
    , (WarningTok, defStyle{ tokenColor = color 0xfab387, tokenBold = True })
    , (DataTypeTok, defStyle{ tokenColor = color 0xf9e2af, tokenBold = True })
    , (ConstantTok, defStyle)
    , (SpecialCharTok, defStyle{ tokenColor = color 0x94e2d5 })
    , (VerbatimStringTok, defStyle{ tokenColor = color 0x94e2d5 })
    , (SpecialStringTok, defStyle{ tokenColor = color 0x94e2d5 })
    , (ImportTok, defStyle)
    , (VariableTok, defStyle{ tokenColor = color 0xb4befe })
    , (ControlFlowTok, defStyle{ tokenColor = color 0x89b4fa })
    , (BuiltInTok, defStyle)
    , (ExtensionTok, defStyle)
    , (PreprocessorTok, defStyle{ tokenColor = color 0xf38ba8 })
    , (DocumentationTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (AnnotationTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (CommentVarTok, defStyle{ tokenColor = color 0xa6e3a1 })
    , (AttributeTok, defStyle)
    , (InformationTok, defStyle{ tokenColor = color 0xa6e3a1 })
    ]
  }
  where
   color :: Int -> Maybe Color
   color = toColor
